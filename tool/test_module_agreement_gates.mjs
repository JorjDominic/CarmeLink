// Disposable in-memory PostgreSQL. No remote services or real agreement wording.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';
const db = new PGlite();
const source = name => readFileSync(`supabase/migrations/${name}`, 'utf8');
const ids = Object.fromEntries(['owner','caretaker','tenant','guardian','other'].map(r => [r,randomUUID()]));
let passed = 0;
const check = async (name, fn) => { await fn(); console.log(`PASS ${++passed}: ${name}`); };
async function actor(role) {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)", [ids[role] ?? '']);
  await db.exec('set role authenticated');
}
const value = async (sql, args=[]) => Object.values((await db.query(sql,args)).rows[0])[0];
const publish = (module,audience='tenant',version='1') => value('select publish_module_agreement($1,$2,$3,$4,true)',
  [module,audience,version,'TEST FIXTURE ONLY. This content is not a real agreement.']);
const accept = id => value('select accept_confidentiality_agreement($1,true,true)',[id]);
const status = module => value('select module_agreement_status($1)',[module]);
const report = () => value('insert into confidential_reports(tenant_id) values($1) returning id',[ids.tenant]);
const gate = () => value("select record_tenant_geofence_transition('IN',now(),$1)",[randomUUID()]);
try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth;
    grant usage on schema auth,public to authenticated;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role text);
    create function current_user_role() returns text language sql security definer as $$select role from public.profiles where id=auth.uid()$$;
    create table confidential_reports(id uuid primary key default gen_random_uuid(),tenant_id uuid references profiles);
    create table confidential_report_addenda(id uuid primary key default gen_random_uuid(),report_id uuid references confidential_reports,body text);
    create table gate_events(id uuid primary key default gen_random_uuid(),tenant_id uuid,direction text,verification_method text,
      status text,checkpoint_type text,checked_at timestamptz,observed_at timestamptz,created_by uuid,client_event_id uuid);
    create unique index gate_events_client_event_id_unique_idx on gate_events(client_event_id) where client_event_id is not null;
    create table curfew_requests(tenant_id uuid,status text,departure_time timestamptz,expected_return_time timestamptz);
    create table location_monitoring_incidents(id uuid primary key default gen_random_uuid(),tenant_id uuid,
      recovered_at timestamptz,dispatch_claimed_until timestamptz,guardian_notified_at timestamptz,
      escalated_at timestamptz,started_at timestamptz default now());
    create function list_confidential_report_addenda(p_report_id uuid) returns jsonb language sql security definer as
      $$ select coalesce(jsonb_agg(to_jsonb(a)),'[]') from public.confidential_report_addenda a where report_id=p_report_id $$;
    alter table confidential_reports enable row level security;
    alter table confidential_report_addenda enable row level security;
    alter table gate_events enable row level security;
    create policy original_gate_access on gate_events for select to authenticated using(tenant_id=auth.uid() or current_user_role() in ('owner','caretaker'));
    create policy original_report_access on confidential_reports to authenticated
      using(tenant_id=auth.uid() or current_user_role() in ('owner','caretaker'));
    create policy original_addendum_access on confidential_report_addenda to authenticated using(true);
    grant select,insert,update on confidential_reports,confidential_report_addenda to authenticated;
    grant select on profiles,gate_events to authenticated;
  `);
  for (const [role,id] of Object.entries(ids)) await db.query('insert into profiles values($1,$2)',[id,role==='other'?'tenant':role]);
  await db.exec(source('202610160007_confidentiality_agreements.sql'));
  const native=source('202609210001_native_tripwire_geofencing.sql');
  await db.exec(native.slice(native.indexOf('create or replace function public.record_tenant_geofence_transition')));
  // Existing acceptance must survive the upgrade.
  await actor('owner');
  const legacy=await value("select publish_confidentiality_agreement('tenant','legacy',$1,true)",['Approved legacy test fixture content only.']);
  await actor('tenant'); const legacyAcceptance=await accept(legacy);
  await db.exec('reset role');
  await db.exec(source('202610180002_module_agreement_gates.sql'));

  await check('upgrade retains confidentiality acceptance but geofencing is independently locked', async () => {
    await actor('tenant'); assert.equal((await status('confidentiality')).allowed,true);
    assert.equal((await status('geofencing')).allowed,false);
    assert.equal(await accept(legacy),legacyAcceptance);
    await assert.rejects(gate,/MODULE_AGREEMENT_REQUIRED/);
    assert.equal(await value('select count(*)::int from gate_events'),0);
    await actor('other'); assert.equal((await status('confidentiality')).allowed,false);
    await assert.rejects(report,/row-level security|MODULE_AGREEMENT_REQUIRED/);
  });
  let confidential,geo,guardian;
  await check('owner publishes separate modules with independent versions and audiences', async () => {
    await actor('owner'); confidential=await publish('confidentiality'); geo=await publish('geofencing'); guardian=await publish('geofencing','guardian');
    assert.notEqual(confidential,geo);
    for (const role of ['tenant','guardian','caretaker']) {
      await actor(role); await assert.rejects(() => publish('geofencing'));
    }
  });
  await check('publishing replacement locks reports, addenda and geofence RPC until explicit current acceptance', async () => {
    await actor('tenant'); assert.equal((await status('confidentiality')).allowed,false);
    await assert.rejects(report,/MODULE_AGREEMENT_REQUIRED|row-level security/);
    await assert.rejects(gate,/MODULE_AGREEMENT_REQUIRED/);
    await assert.rejects(() => value('select accept_confidentiality_agreement($1,false,true)',[confidential]));
    await assert.rejects(() => value('select accept_confidentiality_agreement($1,true,false)',[confidential]));
    await assert.rejects(() => accept(legacy),/newer agreement/);
    await accept(confidential); const id=await report();
    assert.equal((await status('geofencing')).allowed,false);
    await assert.rejects(gate,/MODULE_AGREEMENT_REQUIRED/);
    await accept(geo); assert.ok(await gate());
    await db.query('insert into confidential_report_addenda(report_id,body) values($1,$2)',[id,'Original follow-up']);
    assert.equal((await value('select list_confidential_report_addenda($1)',[id])).length,1);
    await actor('owner'); await publish('confidentiality','tenant','2'); await publish('geofencing','tenant','2');
    await actor('tenant');
    assert.equal(await value('select count(*)::int from confidential_reports'),0);
    assert.equal(await value('select count(*)::int from confidential_report_addenda'),0);
    await assert.rejects(() => value('select list_confidential_report_addenda($1)',[id]),/MODULE_AGREEMENT_REQUIRED/);
    await assert.rejects(() => db.query('insert into confidential_report_addenda(report_id,body) values($1,$2)',[id,'Blocked follow-up']),/MODULE_AGREEMENT_REQUIRED/);
    await assert.rejects(gate,/MODULE_AGREEMENT_REQUIRED/);
  });
  await check('guardian acceptance cannot accept tenant terms or unlock tenant tracking', async () => {
    await actor('guardian'); await assert.rejects(() => accept(geo),/not available/);
    await accept(guardian); assert.equal((await status('geofencing')).allowed,true);
    await actor('tenant'); assert.equal((await status('geofencing')).allowed,false);
    await actor('other'); assert.equal((await status('geofencing')).allowed,false);
  });
  await check('staff management stays available while agreement history and internal readers stay protected', async () => {
    for (const role of ['owner','caretaker']) {
      await actor(role); assert.ok(await report());
      assert.ok((await value('select count(*)::int from confidential_reports'))>0);
    }
    await actor('tenant');
    await assert.rejects(() => value('select list_confidential_report_addenda_core($1)',[randomUUID()]),/permission denied/);
    await assert.rejects(() => db.query('delete from confidentiality_agreement_acceptances'),/permission denied/);
    await db.exec('reset role');
    await assert.rejects(() => db.query("update confidentiality_agreement_versions set module='geofencing' where id=$1",[legacy]),/immutable/);
  });
  await check('current re-acceptance is idempotent and restores module access', async () => {
    await actor('tenant'); const current=(await status('geofencing')).agreement;
    const first=await accept(current.id); assert.equal(await accept(current.id),first);
    assert.equal((await status('geofencing')).allowed,true); assert.ok(await gate());
  });
  await check('agreement-paused tracking does not send location-off alerts', async () => {
    await db.exec('reset role');
    await db.query('insert into location_monitoring_incidents(tenant_id) values($1),($2)',[ids.tenant,ids.other]);
    const claimed=(await db.query('select * from claim_location_monitoring_alerts()')).rows;
    assert.deepEqual(claimed.map(r=>r.tenant_id),[ids.tenant]);
    await actor('owner'); await publish('geofencing','tenant','3');
    await db.exec('reset role'); await db.exec('update location_monitoring_incidents set dispatch_claimed_until=null');
    assert.equal((await db.query('select * from claim_location_monitoring_alerts()')).rows.length,0);
  });
  console.log(`${passed} module agreement database checks passed.`);
} finally { await db.close(); }
