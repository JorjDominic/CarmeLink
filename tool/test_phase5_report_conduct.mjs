// In-memory PostgreSQL only. No credentials, Supabase connection, or production writes.
// node tool/test_phase5_report_conduct.mjs
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
const db = new PGlite();
const source = name => readFileSync(`supabase/migrations/${name}`, 'utf8');
const ids = Object.fromEntries(['owner','caretaker','tenant','other','guardian','missing'].map(role => [role,randomUUID()]));
let passed = 0;
const check = async (label, fn) => { await fn(); passed++; console.log(`PASS ${label}`); };
async function actor(role, api = true) {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)", [ids[role] ?? '']);
  if (api) await db.exec('set role authenticated');
}
const one = async (sql, args = []) => (await db.query(sql,args)).rows[0];
const version = async id => (await one('select updated_at::text as v from public.conduct_cases where id=$1',[id])).v;
const clear = () => db.exec('reset role; truncate app_notifications,notification_push_jobs;');
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth; create schema storage;
    grant usage on schema auth,public to authenticated,anon;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role text,full_name text);
    create function current_user_role() returns text language sql security definer set search_path='' as $$ select role from public.profiles where id=auth.uid() $$;
    create function is_staff() returns boolean language sql security definer set search_path='' as $$ select coalesce(public.current_user_role() in ('owner','caretaker'),false) $$;
    create function set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=clock_timestamp(); return new; end $$;
    create publication supabase_realtime;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid,bucket_id text);
    create table maintenance_reports(id uuid primary key default gen_random_uuid(),tenant_id uuid references profiles,
      status text default 'pending',updated_at timestamptz default now());
    alter table maintenance_reports enable row level security;
    grant select on maintenance_reports to authenticated;
    create policy "staff read maintenance" on maintenance_reports for select to authenticated using (is_staff());
    create policy "staff update maintenance reports" on maintenance_reports for update to authenticated using (is_staff());
    create trigger maintenance_updated before update on maintenance_reports for each row execute function set_updated_at();
    create table app_notifications(id uuid primary key default gen_random_uuid(),recipient_id uuid,
      notification_type text,title text,body text,route_type text,route_id uuid,data jsonb,created_at timestamptz default now());
    create table notification_push_jobs(notification_id uuid primary key);
  `);
  for (const [role,id] of Object.entries(ids)) await db.query('insert into profiles values($1,$2,$3)',[id,role==='other'?'tenant':role==='missing'?null:role,role]);
  await db.exec(source('202609100001_staff_maintenance_workflow.sql'));
  await db.exec(source('202609190003_tenant_confidential_reports.sql'));
  await db.exec(source('202609190004_owner_confidential_report_review.sql'));
  await db.exec(source('20260924070000_phase4a_conduct_cases.sql'));
  await db.exec(source('20260924090000_phase4c_conduct_case_appeals.sql'));
  const helpers=source('202610070012_notification_coverage_completion.sql');
  await db.exec(helpers.slice(helpers.indexOf('create or replace function public.emit_app_notification('),helpers.indexOf('-- Contract/onboarding milestones')));
  const queue=source('202610070005_report_push_delivery.sql');
  await db.exec(queue.slice(queue.indexOf('create or replace function public.queue_server_report_push()'),queue.indexOf('create or replace function public.claim_report_push_jobs()')));
  const saved=source('202610090001_phase2_saved_report_notifications.sql');
  await db.exec(saved.slice(saved.indexOf('create or replace function public.notify_conduct_report_saved_event()'),saved.indexOf('create or replace function public.notify_conduct_appeal_saved_changes()')));
  const caseId=randomUUID(), reportId=randomUUID(), maintenanceId=randomUUID();
  await db.query(`insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,opened_by,tenant_notified_at)
    values($1,$2,'rule_violation','Original incident','Original case description',now(),'awaiting_response',$3,now())`,[caseId,ids.tenant,ids.owner]);
  await db.query("insert into conduct_case_events(case_id,event_type,actor_id,actor_name,notes) values($1,'case_created',$2,'Owner','Legacy internal content')",[caseId,ids.owner]);
  await db.query("insert into confidential_reports(id,tenant_id,category,summary) values($1,$2,'safety_concern','Confidential original submission')",[reportId,ids.tenant]);
  await db.query('insert into maintenance_reports(id,tenant_id) values($1,$2)',[maintenanceId,ids.tenant]);
  await db.exec(source('202610140001_phase5_report_and_conduct_responses.sql'));
  await check('migration preserves legacy case history as internal',async()=>{
    assert.equal((await one("select visibility from conduct_case_events where notes='Legacy internal content'")).visibility,'internal');
    assert.equal((await one('select summary from confidential_reports where id=$1',[reportId])).summary,'Confidential original submission');
  });
  await check('tenant explanation preserved and notifies authorized staff',async()=>{
    await clear(); await actor('tenant');
    await db.query("select submit_conduct_case_response($1,'Original tenant explanation')",[caseId]);
    await actor('owner',false);
    assert.equal((await one('select count(*)::int n from conduct_case_responses')).n,1);
    assert.equal((await one('select status from conduct_cases where id=$1',[caseId])).status,'under_review');
    assert.deepEqual((await db.query('select recipient_id from app_notifications order by recipient_id')).rows.map(r=>r.recipient_id),[ids.owner,ids.caretaker].sort());
  });
  const send=async(body,visibility,key=randomUUID(),v=null) => db.query('select add_conduct_official_response($1,$2,$3,$4,$5) id',[caseId,v??await version(caseId),body,visibility,key]);
  await check('unauthorized tenant/guardian/missing-role/null-session response writes rejected',async()=>{
    for (const role of ['tenant','other','guardian','missing','none']) {
      await actor(role); await assert.rejects(send('Unauthorized response','tenant',randomUUID(),'2026-01-01'));
    }
  });
  const key=randomUUID(); let responseId, stale;
  await check('owner official response is immutable, versioned and does not decide case',async()=>{
    await clear(); await actor('owner'); stale=await version(caseId);
    responseId=(await send('Please provide additional evidence.','tenant',key,stale)).rows[0].id;
    await assert.rejects(db.query("update conduct_case_events set notes='changed' where id=$1",[responseId]));
    assert.equal((await one('select status from conduct_cases where id=$1',[caseId])).status,'under_review');
    await db.exec('reset role');
    const event=await one('select actor_role,visibility from conduct_case_events where id=$1',[responseId]);
    assert.deepEqual(event,{actor_role:'owner',visibility:'tenant'});
    const notifications=(await db.query('select recipient_id,route_type,route_id,body from app_notifications')).rows;
    assert.deepEqual(notifications.map(r=>r.recipient_id).sort(),[ids.tenant,ids.caretaker].sort());
    assert(notifications.every(r=>r.route_type==='conduct_case' && r.route_id===caseId && !r.body.includes('additional evidence')));
    assert.equal((await one('select count(*)::int n from notification_push_jobs')).n,2);
  });
  await check('repeated network retry yields same response and no duplicate notification',async()=>{
    await actor('owner');
    const retry=(await send('Please provide additional evidence.','tenant',key,stale)).rows[0].id;
    assert.equal(retry,responseId);
    await assert.rejects(send('Changed payload','internal',key,stale));
    await db.exec('reset role');
    assert.equal((await one('select count(*)::int n from conduct_case_events where client_request_id=$1',[key])).n,1);
    assert.equal((await one('select count(*)::int n from notification_push_jobs')).n,2);
  });
  await check('stale response and stale conflicting decision rejected without partial event',async()=>{
    await actor('owner');
    await assert.rejects(send('Stale response body','tenant',randomUUID(),stale),/changed/);
    await assert.rejects(db.query("select set_conduct_case_review_status($1,$2,'resolved','Reviewed and resolved')",[caseId,stale]),/changed/);
  });
  await check('caretaker internal entry creates no tenant/guardian notification',async()=>{
    await clear(); await actor('caretaker');
    await send('Private administrative review instructions','internal');
    await db.exec('reset role');
    assert.deepEqual((await db.query('select recipient_id from app_notifications')).rows.map(r=>r.recipient_id),[ids.owner]);
  });
  await check('tenant RPC returns only own published visible responses; direct event API stays restricted',async()=>{
    await actor('tenant');
    const rows=(await db.query('select * from get_my_conduct_official_responses($1)',[caseId])).rows;
    assert.equal(rows.length,1); assert.equal(rows[0].body,'Please provide additional evidence.');
    assert.equal((await one('select count(*)::int n from conduct_case_events')).n,0);
    for (const role of ['other','guardian','missing']) {
      await actor(role); assert.equal((await db.query('select * from get_my_conduct_official_responses($1)',[caseId])).rows.length,0);
    }
    await db.exec('set role anon');
    await assert.rejects(db.query('select * from get_my_conduct_official_responses($1)',[caseId]));
  });
  await check('warning, closure and appeal workflows retain their records',async()=>{
    await actor('owner');
    await db.query("select issue_conduct_case_warning($1,$2,'Formal original warning')",[caseId,await version(caseId)]);
    await actor('tenant');
    const appeal=(await one("select submit_conduct_case_appeal($1,'I request reconsideration of this warning.','Supporting information') id",[caseId])).id;
    await actor('caretaker');
    const appealVersion=(await one('select updated_at::text v from conduct_case_appeals where id=$1',[appeal])).v;
    await db.query("select decide_conduct_case_appeal($1,$2,'accepted','Accepted for administrative reconsideration')",[appeal,appealVersion]);
    await db.query("select set_conduct_case_review_status($1,$2,'resolved','Reviewed and resolved')",[caseId,await version(caseId)]);
    await assert.rejects(send('Cannot modify finalized case','tenant'),/closed/);
    await db.exec('reset role');
    assert.equal((await one('select count(*)::int n from conduct_case_warnings')).n,1);
    assert.equal((await one('select status from conduct_case_appeals where id=$1',[appeal])).status,'accepted');
    assert.equal((await one('select count(*)::int n from conduct_case_responses')).n,1);
  });
  await check('draft cases cannot receive official replies or leak old internal history',async()=>{
    await db.exec('reset role');
    await db.query("update conduct_cases set status='draft',tenant_notified_at=null where id=$1",[caseId]);
    await actor('owner'); await assert.rejects(send('Draft response text','tenant'),/closed/);
    await actor('tenant'); assert.equal((await db.query('select * from get_my_conduct_official_responses($1)',[caseId])).rows.length,0);
  });
  await check('maintenance pending, progress, resolution and invalid/unauthorized transitions',async()=>{
    await actor('owner');
    const maintenanceVersion=async()=>(await one('select updated_at::text v from maintenance_reports where id=$1',[maintenanceId])).v;
    const save=async status=>db.query('select update_staff_maintenance($1,$2,$3,$4)',[maintenanceId,await maintenanceVersion(),status,'Recorded tenant-visible update']);
    await assert.rejects(save('resolved'),/not allowed/);
    await save('in_progress'); await save('resolved');
    await actor('tenant'); await assert.rejects(db.query("select update_staff_maintenance($1,now(),'in_progress','Unapproved change')",[maintenanceId]),/owners and caretakers/);
  });
  const noteKey=randomUUID();
  await check('internal report notes use existing protected history and deduplicate without tenant notifications',async()=>{
    await clear(); await actor('owner');
    for(let i=0;i<2;i++) await db.query("select append_report_internal_note('confidential',$1,'Internal confidential review note',$2)",[reportId,noteKey]);
    await db.exec('reset role');
    assert.equal((await one('select count(*)::int n from confidential_report_audit where client_request_id=$1',[noteKey])).n,1);
    assert.equal((await one('select count(*)::int n from app_notifications')).n,0);
    assert.equal((await one('select response_notes from confidential_reports where id=$1',[reportId])).response_notes,null);
    await actor('tenant');
    await assert.rejects(db.query('select * from get_confidential_report_history($1)',[reportId]),/Staff access/);
    await assert.rejects(db.query('select * from confidential_report_audit'));
    assert.equal((await one('select count(*)::int n from confidential_reports')).n,1);
    await actor('other'); assert.equal((await one('select count(*)::int n from confidential_reports')).n,0);
  });
  await check('confidential guarded triage rejects stale, duplicate and finalized writes through both APIs',async()=>{
    await actor('caretaker');
    await db.exec('reset role'); const old=(await one('select updated_at::text v from confidential_reports where id=$1',[reportId])).v;
    await actor('caretaker');
    await db.query("select review_confidential_report_guarded($1,$2,'under_review','Review has begun')",[reportId,old]);
    await assert.rejects(db.query("select review_confidential_report_guarded($1,$2,'resolved','Stale resolution')",[reportId,old]),/changed/);
    await db.query("select owner_review_confidential_report($1,'resolved','Recorded completed action')",[reportId]);
    await assert.rejects(db.query("select owner_review_confidential_report($1,'under_review','Attempt reopen')",[reportId]),/not allowed/);
    await assert.rejects(db.query("select append_report_internal_note('confidential',$1,'Late internal entry',$2)",[reportId,randomUUID()]),/finalized/);
  });
  await check('notification failure rolls back a new official response',async()=>{
    await db.exec('reset role');
    await db.query("update conduct_cases set status='under_review',tenant_notified_at=now() where id=$1",[caseId]);
    const before=(await one('select count(*)::int n from conduct_case_events')).n;
    await db.exec("alter table app_notifications add constraint test_delivery_failure check(false) not valid");
    await actor('owner'); await assert.rejects(send('Entry must roll back','tenant'));
    await db.exec('reset role');
    assert.equal((await one('select count(*)::int n from conduct_case_events')).n,before);
    await db.exec('alter table app_notifications drop constraint test_delivery_failure');
  });
  await check('additional tenant explanations invalidate stale administrative replies without resolving case',async()=>{
    await actor('owner'); const before=await version(caseId);
    await actor('tenant'); await db.query("select submit_conduct_case_response($1,'Additional supporting tenant explanation')",[caseId]);
    await actor('owner'); await assert.rejects(send('Reply based on an older explanation','tenant',randomUUID(),before),/changed/);
    assert.equal((await one('select status from conduct_cases where id=$1',[caseId])).status,'under_review');
  });
  await check('maintenance internal notes never enter tenant-readable update and remain staff-only',async()=>{
    await clear();
    const id=randomUUID(), request=randomUUID();
    await db.query('insert into maintenance_reports(id,tenant_id) values($1,$2)',[id,ids.tenant]);
    await actor('caretaker');
    for(let i=0;i<2;i++) await db.query("select append_report_internal_note('maintenance',$1,'Private maintenance instructions',$2)",[id,request]);
    const rows=(await db.query('select * from maintenance_staff_history where report_id=$1',[id])).rows;
    assert.equal(rows.length,1);assert.match(rows[0].notes,/Internal note/);
    await db.exec('reset role');
    assert.equal((await one('select staff_notes from maintenance_reports where id=$1',[id])).staff_notes,'');
    assert.equal((await one('select count(*)::int n from app_notifications')).n,0);
    for(const role of ['tenant','other','guardian','missing','none']) {
      await actor(role);
      assert.equal((await one('select count(*)::int n from maintenance_staff_history')).n,0);
      await assert.rejects(db.query("select append_report_internal_note('maintenance',$1,'Unauthorized internal note',$2)",[id,randomUUID()]),/Staff access/);
    }
  });
  await check('tenant-visible response chronology and server author metadata are preserved',async()=>{
    await actor('owner'); await send('Later official tenant response','tenant');
    await actor('tenant');
    const rows=(await db.query('select * from get_my_conduct_official_responses($1)',[caseId])).rows;
    assert.equal(rows[0].id,responseId);
    assert.equal(rows.at(-1).body,'Later official tenant response');
    assert(rows.every(row=>row.actor_role==='owner' && row.actor_name==='owner'));
  });
  console.log(`${passed} Phase 5 isolated PostgreSQL checks passed.`);
} finally { await db.close(); }
