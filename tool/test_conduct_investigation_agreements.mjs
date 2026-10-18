import { checkSystemMaintenance } from './system_maintenance_checks.mjs';
// In-memory PostgreSQL only. No credentials, Supabase connection, or production writes.
// node tool/test_conduct_investigation_agreements.mjs
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
// Optional independent local PostgreSQL run. Refuse remote/non-disposable databases.
let db;
const configAt=process.argv.indexOf('--local-config');
if(configAt>=0) {
  assert.ok(process.argv.includes('--disposable'),'Explicit disposable flag required');
  const config=JSON.parse(readFileSync(process.argv[configAt+1],'utf8'));
  const address=new URL(config.connectionString);
  assert.ok(['127.0.0.1','localhost','[::1]'].includes(address.hostname));
  assert.match(address.pathname,/^\/carmelink_conduct_validation_[a-z0-9_]+$/);
  const {default:pg}=await import('../build/phase2_sql_tests/node_modules/pg/lib/index.js');
  const client=new pg.Client({connectionString:config.connectionString});await client.connect();
  assert.equal(Number((await client.query("select count(*) n from pg_tables where schemaname='public'")).rows[0].n),0,'Refusing a nonempty database');
  db={query:(sql,args)=>client.query(sql,args),exec:sql=>client.query(sql),close:()=>client.end()};
} else db=new PGlite();
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
    do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if; if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if; end $$;
    create schema auth; create schema storage;
    grant usage on schema auth,public to authenticated,anon;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role text,full_name text);
    create function current_user_role() returns text language sql security definer set search_path='' as $$ select role from public.profiles where id=auth.uid() $$;
    create function is_staff() returns boolean language sql security definer set search_path='' as $$ select coalesce(public.current_user_role() in ('owner','caretaker'),false) $$;
    create function set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=clock_timestamp(); return new; end $$;
    create publication supabase_realtime;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,metadata jsonb,owner_id text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;
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
  await db.exec(source('202610140001_phase5_report_and_conduct_responses.sql'));
  const legacyCase=randomUUID(),legacyEvidence=randomUUID();
  await db.query(`insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,opened_by,tenant_notified_at)
    values($1,$2,'rule_violation','Legacy resolved case','Original historical description',now(),'resolved',$3,now())`,[legacyCase,ids.other,ids.owner]);
  await db.query("insert into conduct_case_events(case_id,event_type,actor_id,actor_name,notes) values($1,'resolved',$2,'Original owner','Original resolution notes')",[legacyCase,ids.owner]);
  await db.query("insert into storage.objects(bucket_id,name,metadata) values('conduct_case_evidence','legacy-unscoped-image.png','{}')");
  await db.query(`insert into conduct_case_evidence(id,case_id,storage_path,original_name,content_type,size_bytes,caption,uploaded_by)
    values($1,$2,'legacy-unscoped-image.png','Original image.png','image/png',123,'Original historical caption',$3)`,[legacyEvidence,legacyCase,ids.owner]);
  await db.exec(source('202610160006_conduct_investigation_evidence.sql'));
  await db.exec(source('202610160007_confidentiality_agreements.sql'));
  await check('upgrade preserves legacy closed cases, decisions and nonconforming historical evidence without inferred confirmation',async()=>{
    await actor('owner');
    const legacy=(await one('select get_conduct_investigation($1) data',[legacyCase])).data;
    assert.equal(legacy.counts.confirmed,0);assert.equal(legacy.counts.closed_without_outcome,1);
    const evidence=await one('select * from conduct_case_evidence where id=$1',[legacyEvidence]);
    assert.equal(evidence.caption,'Original historical caption');assert.equal(evidence.storage_path,'legacy-unscoped-image.png');
    assert.equal((await one('select description from conduct_cases where id=$1',[legacyCase])).description,'Original historical description');
    await db.exec('reset role');await assert.rejects(db.query("delete from storage.objects where name='legacy-unscoped-image.png'"),/cannot be replaced/);
  });
  const createCase=async({status='awaiting_response',sourceId=null,published=true}={})=>{
    await actor('owner',false); const id=randomUUID();
    await db.query(`insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,opened_by,tenant_notified_at,source_module,source_record_id)
      values($1,$2,'rule_violation','Original incident','Original incident description',now(),$3,$4,$5,$6,$7)`,
      [id,ids.tenant,status,ids.owner,published?'2026-10-16':null,sourceId?'curfew':'manual',sourceId]);
    return id;
  };
  const caseId=await createCase();
  const stats=async(id=caseId)=>(await one('select get_conduct_investigation($1) data',[id])).data;
  const decide=async(id,outcome='confirmed',reason='Evidence reviewed and decision documented',key=randomUUID(),appeal=null,v=null)=>
    (await one('select record_conduct_investigation_decision($1,$2,$3,$4,$5,$6) id',[id,v??await version(id),outcome,reason,key,appeal])).id;
  await check('reports and warnings are not confirmed; original tenant explanation and report survive',async()=>{
    await actor('tenant'); await db.query("select submit_conduct_case_response($1,'Original explanation remains on file')",[caseId]);
    await actor('caretaker'); await db.query("select issue_conduct_case_warning($1,$2,'Existing authorized caretaker warning')",[caseId,await version(caseId)]);
    assert.equal((await stats()).counts.confirmed,0);
    assert.equal((await stats()).counts.pending,1);
    await actor('owner',false);
    assert.equal((await one('select description from conduct_cases where id=$1',[caseId])).description,'Original incident description');
    assert.equal((await one('select count(*)::int n from conduct_case_responses where case_id=$1',[caseId])).n,1);
  });
  await check('confirmation requires Owner, documented reason, publication and fresh version',async()=>{
    for(const role of ['caretaker','tenant','other','guardian','missing','none']) {
      await actor(role); await assert.rejects(decide(caseId,'confirmed','Valid documented reason',randomUUID(),null,'2026-01-01'));
    }
    await actor('owner');
    await assert.rejects(decide(caseId,'confirmed','bad'));
    await assert.rejects(decide(caseId,'confirmed','A valid reason',randomUUID(),null,'2026-01-01'),/changed/);
    const draft=await createCase({status:'draft',published:false}); await actor('owner'); await assert.rejects(decide(draft),/Publish/);
  });
  const decisionKey=randomUUID(); let savedDecision,oldVersion;
  await check('explicit confirmation stores actor/reason/time, notifies correct route and never closes case',async()=>{
    await clear();await actor('owner');oldVersion=await version(caseId); savedDecision=await decide(caseId,'confirmed','Reviewed evidence supports confirmation',decisionKey);
    const result=await stats(); assert.equal(result.counts.confirmed,1);assert.equal(result.decisions[0].outcome,'confirmed');
    assert.equal(result.decisions[0].actor_name,'owner');assert.ok(result.decisions[0].created_at);
    assert.equal((await one('select status from conduct_cases where id=$1',[caseId])).status,'warning_issued');
    await db.exec('reset role');const notices=(await db.query('select recipient_id,route_type,route_id from app_notifications')).rows;
    assert.ok(notices.some(n=>n.recipient_id===ids.tenant));assert.ok(notices.every(n=>n.route_type==='conduct_case'&&n.route_id===caseId));
    await actor('owner');assert.equal(await decide(caseId,'confirmed','Reviewed evidence supports confirmation',decisionKey,null,oldVersion),savedDecision);
    await assert.rejects(decide(caseId,'confirmed','Changed decision reason',decisionKey));
    await assert.rejects(db.query("select add_conduct_official_response($1,$2,'Reviewed evidence supports confirmation','tenant',$3)",[caseId,await version(caseId),decisionKey]),/conflict/);
    await db.exec('reset role');assert.equal((await one('select count(*)::int n from conduct_case_events where client_request_id=$1',[decisionKey])).n,1);
  });
  let duplicate,second;
  await check('multiple confirmations, duplicate linked incidents, pending/dismissed/resolved exclusions',async()=>{
    const sourceId=randomUUID(); second=await createCase({sourceId});duplicate=await createCase({sourceId});
    const dismissed=await createCase(),resolved=await createCase(),pending=await createCase();
    await actor('owner');await decide(second);await decide(duplicate);
    await db.query("select set_conduct_case_review_status($1,$2,'dismissed','Insufficient supporting evidence')",[dismissed,await version(dismissed)]);
    await db.query("select set_conduct_case_review_status($1,$2,'resolved','Administratively resolved without confirmation')",[resolved,await version(resolved)]);
    await assert.rejects(decide(resolved),/closed/);
    const c=(await stats()).counts;assert.equal(c.confirmed,2);assert.equal(c.total,6);assert.equal(c.pending,1);assert.equal(c.unconfirmed,1);assert.equal(c.closed_without_outcome,1);
    await db.query("select set_conduct_case_review_status($1,$2,'dismissed','Dismissed after review')",[duplicate,await version(duplicate)]);
    assert.equal((await stats()).counts.confirmed,2);
    await decide(pending,'not_confirmed','Available evidence does not establish the allegation');
    assert.equal((await stats()).counts.unconfirmed,3);
  });
  await check('accepted appeal alone preserves confirmation; explicit documented overturn changes count without rewriting history',async()=>{
    await actor('tenant'); const appeal=(await one("select submit_conduct_case_appeal($1,'Please reconsider the recorded warning.','Supporting explanation') id",[caseId])).id;
    await actor('owner');await assert.rejects(decide(caseId,'overturned','Review accepted appeal',randomUUID(),appeal),/accepted appeal/);
    const av=(await one('select updated_at::text v from conduct_case_appeals where id=$1',[appeal])).v;
    await actor('caretaker');await db.query("select decide_conduct_case_appeal($1,$2,'accepted','Accepted for reconsideration')",[appeal,av]);
    assert.equal((await stats()).counts.confirmed,2);
    await db.query("select set_conduct_case_review_status($1,$2,'resolved','Existing closure permitted after appeal review')",[caseId,await version(caseId)]);
    await actor('owner');await decide(caseId,'overturned','Accepted appeal evidence overturns the finding',randomUUID(),appeal);
    assert.equal((await stats()).counts.confirmed,1);assert.equal((await stats()).counts.appealed,1);
    assert.equal((await stats()).decisions.length,2);
    assert.equal((await one('select count(*)::int n from conduct_case_warnings where case_id=$1',[caseId])).n,1);
  });
  await check('tenant/staff counts agree; other tenants, guardians and null sessions cannot read investigation or internal notes',async()=>{
    await actor('owner');const expected=await stats();
    await actor('tenant');assert.deepEqual(await stats(),expected);
    assert.equal((await one('select count(*)::int n from conduct_case_events')).n,0);
    for(const role of ['other','guardian','missing','none']) {await actor(role);await assert.rejects(stats(),/not available/);}
  });
  const evidencePath=`${caseId}/${randomUUID()}.png`;
  const register=async(path=evidencePath,caption='Original evidence caption')=>(await one("select register_conduct_case_evidence($1,$2,'evidence.png','image/png',123,$3) id",[caseId,path,caption])).id;
  await check('evidence requires uploaded object, correct case path, matching metadata and actual uploader',async()=>{
    await actor('caretaker');await assert.rejects(register(),/Upload/);
    await assert.rejects(register(`${randomUUID()}/image.png`),/Invalid/);
    await db.query("insert into storage.objects(bucket_id,name,metadata,owner_id) values('conduct_case_evidence',$1,'{\"size\":123,\"mimetype\":\"image/png\"}',$2)",[evidencePath,ids.caretaker]);
    await actor('owner');await assert.rejects(register(),/upload/);
    await actor('caretaker');await assert.rejects(db.query("select register_conduct_case_evidence($1,$2,'evidence.png','image/png',999,'')",[caseId,evidencePath]),/metadata/);
  });
  await check('evidence registration retries are idempotent, preserve attribution and cannot replace/delete historical files',async()=>{
    await actor('caretaker');const id=await register();assert.equal(await register(),id);await assert.rejects(register(evidencePath,'Changed caption'),/conflict/);
    const row=await one('select * from conduct_case_evidence where id=$1',[id]);assert.equal(row.uploaded_by,ids.caretaker);assert.ok(row.created_at);
    assert.equal((await db.query('update storage.objects set metadata=\'{"size":10}\' where name=$1 returning id',[evidencePath])).rows.length,0);
    assert.equal((await db.query('delete from storage.objects where name=$1 returning id',[evidencePath])).rows.length,0);
    await db.exec('reset role');await assert.rejects(db.query('delete from storage.objects where name=$1',[evidencePath]),/cannot be replaced/);
    await actor('caretaker');
    await assert.rejects(db.query('delete from conduct_case_evidence where id=$1',[id]));
    assert.equal((await one('select count(*)::int n from conduct_case_evidence where case_id=$1',[caseId])).n,1);
    const orphan=`${caseId}/orphan.png`;
    await db.query("insert into storage.objects(bucket_id,name,owner_id) values('conduct_case_evidence',$1,$2)",[orphan,ids.caretaker]);
    await db.query('delete from storage.objects where name=$1',[orphan]);
    for(const role of ['tenant','other','guardian']) {await actor(role);assert.equal((await one('select count(*)::int n from conduct_case_evidence')).n,0);assert.equal((await one('select count(*)::int n from storage.objects')).n,0);await assert.rejects(register());}
  });
  await check('final schema preserves official/internal response privacy and notification rollback',async()=>{
    await actor('caretaker');
    await db.query("select add_conduct_official_response($1,$2,'Private investigation instructions','internal',$3)",[second,await version(second),randomUUID()]);
    await actor('owner');
    await db.query("select add_conduct_official_response($1,$2,'Public administrative response','tenant',$3)",[second,await version(second),randomUUID()]);
    await actor('tenant');const visible=(await db.query('select * from get_my_conduct_official_responses($1)',[second])).rows;
    assert.equal(visible.length,1);assert.equal(visible[0].body,'Public administrative response');
    await actor('guardian');assert.equal((await db.query('select * from get_my_conduct_official_responses($1)',[second])).rows.length,0);
    await actor('owner',false);const before=(await one('select count(*)::int n from conduct_case_events')).n;
    await db.exec('alter table app_notifications add constraint test_decision_delivery_failure check(false) not valid');
    await actor('owner');await assert.rejects(decide(second,'not_confirmed','This failed notification must roll back the outcome'));
    await actor('owner',false);assert.equal((await one('select count(*)::int n from conduct_case_events')).n,before);
    await db.exec('alter table app_notifications drop constraint test_decision_delivery_failure');
  });
  const publish=async(audience='tenant',version='1',content='APPROVED TEST FIXTURE ONLY. This text is not a published legal agreement.')=>
    (await one('select publish_confidentiality_agreement($1,$2,$3,true) id',[audience,version,content])).id;
  const accept=async(id,reviewed=true,accepted=true)=>(await one('select accept_confidentiality_agreement($1,$2,$3) id',[id,reviewed,accepted])).id;
  let tenantAgreement,guardianAgreement,acceptance;
  await check('no placeholder or mandatory agreement seeded; only Owner publishes approved immutable version',async()=>{
    await actor('owner');assert.equal((await one('select count(*)::int n from confidentiality_agreement_versions')).n,0);
    await assert.rejects(db.query("select publish_confidentiality_agreement('tenant','1','A complete approved test agreement.',false)"),/approved/);
    for(const role of ['caretaker','tenant','guardian','other','none']) {await actor(role);await assert.rejects(publish());}
    await actor('owner');tenantAgreement=await publish();guardianAgreement=await publish('guardian');assert.equal(await publish(),tenantAgreement);
    await assert.rejects(publish('tenant','1','Different content for the same immutable version'),/different content/);
    await assert.rejects(db.query("update confidentiality_agreement_versions set content='Edited' where id=$1",[tenantAgreement]));
  });
  await check('tenant acceptance requires explicit review and acceptance; backend saves own identifier/time and retries once',async()=>{
    await actor('tenant');await assert.rejects(accept(tenantAgreement,false));await assert.rejects(accept(tenantAgreement,true,false));
    await assert.rejects(accept(guardianAgreement),/not available/);
    acceptance=await accept(tenantAgreement);assert.equal(await accept(tenantAgreement),acceptance);
    const row=await one('select * from confidentiality_agreement_acceptances where id=$1',[acceptance]);assert.equal(row.user_id,ids.tenant);assert.equal(row.agreement_id,tenantAgreement);assert.ok(row.accepted_at);
    await assert.rejects(db.query("update confidentiality_agreement_acceptances set accepted_at=now() where id=$1",[acceptance]));
    await assert.rejects(db.query('delete from confidentiality_agreement_acceptances where id=$1',[acceptance]));
    await assert.rejects(db.query('insert into confidentiality_agreement_acceptances(agreement_id,user_id) values($1,$2)',[tenantAgreement,ids.other]));
  });
  await check('guardian accepts only own audience; no cross-user acceptance visibility or caretaker expansion',async()=>{
    await actor('guardian');await accept(guardianAgreement);await assert.rejects(accept(tenantAgreement));
    assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances')).n,1);
    assert.equal((await one('select count(*)::int n from confidentiality_agreement_versions')).n,1);
    await actor('other');assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances')).n,0);
    await actor('caretaker');assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances')).n,0);assert.equal((await one('select count(*)::int n from confidentiality_agreement_versions')).n,0);
    await actor('owner');assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances')).n,2);await assert.rejects(accept(tenantAgreement));
  });
  await check('new version retains exact old text and acceptance; stale unaccepted versions rejected, old retries safe',async()=>{
    await actor('owner');const next=await publish('tenant','2','APPROVED TEST FIXTURE ONLY. Revised version content is retained independently.');
    await actor('other');await assert.rejects(accept(tenantAgreement),/newer/);await accept(next);
    await actor('tenant');assert.equal(await accept(tenantAgreement),acceptance);await accept(next);
    assert.equal((await one('select count(*)::int n from confidentiality_agreement_acceptances')).n,2);
    assert.equal((await one('select content from confidentiality_agreement_versions where id=$1',[tenantAgreement])).content,'APPROVED TEST FIXTURE ONLY. This text is not a published legal agreement.');
    await actor('owner',false);await assert.rejects(db.query('delete from confidentiality_agreement_acceptances where id=$1',[acceptance]),/immutable/);
    await assert.rejects(db.query('update confidentiality_agreement_versions set version=\'edited\' where id=$1',[tenantAgreement]),/immutable/);
  });
  for (const role of ['owner','caretaker']) {
    await check(`${role} retains warnings, termination-review recommendations, appeal decisions, resolution and dismissal`, async()=>{
      const active=await createCase();await actor(role);
      await db.query("select issue_conduct_case_warning($1,$2,'Reviewed documented warning')",[active,await version(active)]);
      assert.equal((await one('select issued_by from conduct_case_warnings where case_id=$1',[active])).issued_by,ids[role]);
      await db.query("select recommend_conduct_termination_review($1,$2,'Documented recommendation for review only')",[active,await version(active)]);
      await actor('tenant');
      const appeal=(await one("select submit_conduct_case_appeal($1,'Please review this documented recommendation.','Fixture evidence') id",[active])).id;
      await actor(role);
      const appealVersion=(await one('select updated_at::text v from conduct_case_appeals where id=$1',[appeal])).v;
      await db.query("select decide_conduct_case_appeal($1,$2,'accepted','Reviewed administrative appeal decision')",[appeal,appealVersion]);
      await db.query("select set_conduct_case_review_status($1,$2,'resolved','Reviewed and resolved with documented notes')",[active,await version(active)]);
      assert.equal((await one('select status from conduct_cases where id=$1',[active])).status,'resolved');
      assert.equal((await one('select status from conduct_case_appeals where id=$1',[appeal])).status,'accepted');
      const dismissed=await createCase();await actor(role);
      await db.query("select set_conduct_case_review_status($1,$2,'dismissed','Reviewed evidence does not support this allegation')",[dismissed,await version(dismissed)]);
      assert.equal((await one('select status from conduct_cases where id=$1',[dismissed])).status,'dismissed');
      const events=(await db.query("select actor_id from conduct_case_events where case_id=any($1::uuid[]) and event_type in ('warning_issued','termination_review_recommended','resolved','dismissed')",[[active,dismissed]])).rows;
      assert.equal(events.length,4);assert.ok(events.every(event=>event.actor_id===ids[role]));
    });
  }
  await checkSystemMaintenance({db, ids, actor, check});
  console.log(`${passed} conduct investigation, evidence, agreement and system maintenance database checks passed.`);
} catch(error) { console.error(error.message);process.exitCode=1; }
finally { await db.close(); }
