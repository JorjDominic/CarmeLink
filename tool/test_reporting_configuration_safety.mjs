// Disposable in-memory PostgreSQL only. No network, keys or Supabase project.
// npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite
// node tool/test_reporting_configuration_safety.mjs
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
const db = new PGlite();
const source = name => readFileSync(`supabase/migrations/${name}`, 'utf8').replaceAll('\r\n', '\n');
const table = (sql, name) => sql.match(new RegExp(`create table(?: if not exists)? public\\.${name} \\([\\s\\S]*?\\n\\);`))[0];
const ids = Object.fromEntries(['owner', 'caretaker', 'tenant', 'other', 'guardian'].map(r => [r, randomUUID()]));
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
let passed = 0;
async function check(label, fn) { await fn(); console.log(`PASS ${++passed}: ${label}`); }
async function actor(role, api = true) {
  await db.exec('reset role');
  await db.query("select set_config('test.actor',$1,false)", [ids[role] ?? '']);
  if (api) await db.exec('set role authenticated');
}
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    grant usage on schema auth,public to authenticated,anon;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role text,full_name text);
    create function current_user_role() returns text language sql security definer set search_path='' as $$select role from public.profiles where id=auth.uid()$$;
    create function is_owner() returns boolean language sql security definer set search_path='' as $$select coalesce(public.current_user_role()='owner',false)$$;
    create function is_staff() returns boolean language sql security definer set search_path='' as $$select coalesce(public.current_user_role() in ('owner','caretaker'),false)$$;
    create function conduct_actor_name() returns text language sql security definer set search_path='' as $$select full_name from public.profiles where id=auth.uid()$$;
    create table rooms(id uuid primary key default gen_random_uuid(),room_number text,is_active boolean default true);
    create table bed_spaces(id uuid primary key default gen_random_uuid(),room_id uuid references rooms);
    create table tenant_assignments(tenant_id uuid references profiles,bed_space_id uuid references bed_spaces,status text);
    create table maintenance_reports(id uuid primary key default gen_random_uuid(),tenant_id uuid references profiles,
      category text,location text,description text,created_at timestamptz default now(),room_id uuid references rooms);`);
  for (const [role, id] of Object.entries(ids)) await db.query('insert into profiles values($1,$2,$3)', [id, role === 'other' ? 'tenant' : role, role]);
  await db.exec(source('202609190003_tenant_confidential_reports.sql'));
  await db.exec(source('202609190004_owner_confidential_report_review.sql'));
  const staff = source('202610060002_staff_report_notification_access.sql');
  await db.exec(staff.slice(staff.indexOf('create or replace function public.owner_list_confidential_reports()'), staff.indexOf('create or replace function public.notify_confidential_report_change()')));
  const preConfiguration = await one("insert into maintenance_reports(category,location,created_at) values('Retired legacy category','Retired legacy area','2000-01-01Z') returning *");
  await db.exec(source('202610070006_dormitory_configuration_and_report_addenda.sql'));
  const conduct = source('20260924070000_phase4a_conduct_cases.sql');
  const inspection = source('20260924060000_phase3b_room_inspections.sql');
  for (const [sql, name] of [[conduct,'conduct_cases'],[conduct,'conduct_case_events'],[inspection,'room_inspections'],[inspection,'room_inspection_findings']]) await db.exec(table(sql,name));
  await db.exec('alter table conduct_cases add column category_detail text,add column source_detail text;');
  const identity = source('202610070011_dynamic_configuration_and_room_identity.sql');
  await db.exec(identity.slice(identity.indexOf('create or replace function public.link_maintenance_room()'), identity.indexOf('-- Rename/merge all rooms')));
  // 011 expands this check; its unrelated payments/room write functions are excluded.
  await db.exec(`alter table dormitory_options drop constraint dormitory_options_group_key_check;
    alter table dormitory_options add constraint dormitory_options_group_key_check check(group_key in ('maintenance_category','common_area','report_type','announcement_category','payment_method'));
    alter table dormitory_options add column instructions text not null default '';`);
  await db.exec(source('202610070013_final_choice_standardization.sql'));
  await db.exec(source('202610090003_configured_concern_snapshot_safety.sql'));
  await db.exec(source('202610160001_configurable_business_categories.sql'));
  const otherCategory = (await one("select id from dormitory_options where group_key='maintenance_category' and code='other'")).id;
  const otherLocation = (await one("select id from dormitory_options where group_key='common_area' and code='other_common_area'")).id;
  let legacy;
  await check('reproduces baseline missing Specify, arbitrary location and client timestamp gaps', async () => {
    legacy = await one("insert into maintenance_reports(category,location,created_at) values('Other','Unsupported location','2001-01-01Z') returning *");
    assert.equal(legacy.specific_category,null);
    assert.equal(legacy.created_at.getUTCFullYear(),2001);
  });
  await db.exec(source('202610160003_reporting_configuration_safety.sql'));
  await check('upgrade preserves historical timestamp/location and allows unchanged legacy review', async () => {
    const row = await one('update maintenance_reports set description=$1 where id=$2 returning *',['Reviewed original',legacy.id]);
    assert.equal(row.created_at.toISOString(),legacy.created_at.toISOString());
    assert.equal(row.location,legacy.location);
    const unlinked=await one('update maintenance_reports set description=$1 where id=$2 returning *',['Reviewed legacy record',preConfiguration.id]);
    assert.equal(unlinked.category,preConfiguration.category);
    assert.equal(unlinked.category_option_id,null);
    assert.equal(unlinked.created_at.toISOString(),preConfiguration.created_at.toISOString());
  });
  const room = await one("insert into rooms(room_number) values('204') returning id");
  const bed = await one('insert into bed_spaces(room_id) values($1) returning id',[room.id]);
  await db.query("insert into tenant_assignments values($1,$2,'active')",[ids.tenant,bed.id]);
  const createMaintenance = (category, location = 'Room 204', categoryId = null, locationId = null) => one(
    'insert into maintenance_reports(tenant_id,category,location,category_option_id,location_option_id) values($1,$2,$3,$4,$5) returning *',
    [ids.tenant,category,location,categoryId,locationId]);
  await check('maintenance Other category and location require Specify at backend', async () => {
    await assert.rejects(createMaintenance('Other'), /specify the maintenance category/);
    await assert.rejects(createMaintenance('Plumbing','Other common area',null,otherLocation), /specify the maintenance location/);
    const saved = await one("insert into maintenance_reports(category,location,location_option_id,specific_category,specific_location) values('Other','Other common area',$1,'  Roof leak  ','  Gate  ') returning *",[otherLocation]);
    assert.equal(saved.specific_category,'Roof leak'); assert.equal(saved.specific_location,'Gate');
    const changed = await one("update maintenance_reports set category_option_id=(select id from dormitory_options where group_key='maintenance_category' and code='plumbing'),location_option_id=null,location='Room 204' where id=$1 returning *",[saved.id]);
    assert.equal(changed.specific_category,null); assert.equal(changed.specific_location,null);
    const customCategory=await one("insert into dormitory_options(group_key,label) values('maintenance_category','Other uncommon issues') returning id");
    const customArea=await one("insert into dormitory_options(group_key,label) values('common_area','Other uncommon areas') returning id");
    const historical=await one("insert into maintenance_reports(category,category_option_id,location,location_option_id,specific_category,specific_location) values('Other uncommon issues',$1,'Other uncommon areas',$2,'Specified original issue','Specified original area') returning id",[customCategory.id,customArea.id]);
    await db.query("update dormitory_options set label='General issues' where id=$1",[customCategory.id]);
    await db.query("update dormitory_options set label='General areas' where id=$1",[customArea.id]);
    const preserved=await one("update maintenance_reports set description='Reviewed after rename' where id=$1 returning *",[historical.id]);
    assert.equal(preserved.category,'Other uncommon issues');
    assert.equal(preserved.specific_category,'Specified original issue');
    assert.equal(preserved.location,'Other uncommon areas');
    assert.equal(preserved.specific_location,'Specified original area');
  });
  const createConcern = option => one("insert into confidential_reports(tenant_id,category,report_type_id,summary) values($1,'other',$2,'Private original concern') returning *",[ids.tenant,option]);
  const createCase = label => one("select create_conduct_case($1,$2,'Valid case title','Original incident description','2026-01-01Z') id",[ids.tenant,label]);
  for (const group of ['maintenance_category','common_area','report_type','conduct_category']) {
    await check(`${group}: Owner add/rename/archive/restore; original label and ID preserved`, async () => {
      await actor('owner');
      const option = await one('insert into dormitory_options(group_key,label,category_code) values($1,$2,$3) returning *',[group,`Custom ${group}`,group==='report_type'?'other':null]);
      await db.exec('reset role');
      let report;
      if (group==='maintenance_category') report = await createMaintenance(option.label);
      if (group==='common_area') report = await createMaintenance('Plumbing',option.label,null,option.id);
      if (group==='report_type') report = await createConcern(option.id);
      if (group==='conduct_category') report = await createCase(option.label);
      await actor('owner');
      await db.query('update dormitory_options set label=$1 where id=$2',[`Renamed ${group}`,option.id]);
      await assert.rejects(db.query('insert into dormitory_options(group_key,label,category_code) values($1,$2,$3)',[group,` RENAMED ${group.toUpperCase()} `,group==='report_type'?'other':null]));
      await db.query('update dormitory_options set is_active=false where id=$1',[option.id]);
      await db.exec('reset role');
      if (group==='maintenance_category') {
        await assert.rejects(createMaintenance(`Renamed ${group}`));
        const old=await one('update maintenance_reports set description=$1 where id=$2 returning *',['Reviewed',report.id]);
        assert.equal(old.category,option.label); assert.equal(old.category_option_id,option.id);
      } else if (group==='common_area') {
        await assert.rejects(createMaintenance('Plumbing',`Renamed ${group}`,null,option.id));
        const old=await one('update maintenance_reports set description=$1 where id=$2 returning *',['Reviewed',report.id]);
        assert.equal(old.location,option.label); assert.equal(old.location_option_id,option.id);
      } else if (group==='report_type') {
        await assert.rejects(createConcern(option.id));
        const old=await one("update confidential_reports set status='under_review' where id=$1 returning *",[report.id]);
        assert.equal(old.report_type_label,option.label); assert.equal(old.report_type_id,option.id);
      } else {
        await assert.rejects(createCase(`Renamed ${group}`));
        const old=await one('update conduct_cases set category=category where id=$1 returning *',[report.id]);
        assert.equal(old.category,option.label);
      }
      await actor('owner');
      const restored = await one('update dormitory_options set is_active=true where id=$1 returning *',[option.id]);
      assert.equal(restored.id,option.id); assert.equal(restored.code,option.code);
      await db.exec('reset role');
      if(group==='maintenance_category') assert.equal((await createMaintenance(restored.label)).category,restored.label);
      if(group==='common_area') assert.equal((await createMaintenance('Plumbing',restored.label,null,option.id)).location,restored.label);
      if(group==='report_type') assert.equal((await createConcern(option.id)).report_type_label,restored.label);
      if(group==='conduct_category') assert.ok((await createCase(restored.label)).id);
    });
  }
  await check('room rename/archive/restore uses authoritative assigned rooms and retains history', async () => {
    const old=await createMaintenance('Plumbing'); assert.equal(old.room_id,room.id);
    await db.query("update rooms set room_number='205' where id=$1",[room.id]);
    await actor('tenant');
    assert.deepEqual((await db.query('select * from list_maintenance_room_locations()')).rows.map(r=>r.location_label),['Room 205','Room 205 • Bathroom']);
    await db.exec('reset role');
    await assert.rejects(createMaintenance('Plumbing','Room 204'));
    await db.query('update rooms set is_active=false where id=$1',[room.id]);
    await actor('tenant'); assert.equal((await db.query('select * from list_maintenance_room_locations()')).rows.length,0);
    await db.exec('reset role'); await assert.rejects(createMaintenance('Plumbing','Room 205'));
    const historical=await one('update maintenance_reports set description=$1 where id=$2 returning *',['Historical room',old.id]);
    assert.equal(historical.location,'Room 204'); assert.equal(historical.room_id,room.id);
    await db.query('update rooms set is_active=true where id=$1',[room.id]);
    assert.equal((await createMaintenance('Plumbing','Room 205 • Bathroom')).room_id,room.id);
  });
  await check('all report submission timestamps are server-generated, immutable and separate from incident time', async () => {
    const m=await one("insert into maintenance_reports(category,location,created_at) values('Plumbing','Room 205','2000-01-01Z') returning id,created_at");
    const c=await one("insert into confidential_reports(tenant_id,category,created_at,summary) values($1,'safety_concern','2000-01-01Z','Original private report') returning id,created_at",[ids.tenant]);
    await actor('owner',false); const k=await createCase('Curfew');
    for(const [name,row] of [['maintenance_reports',m],['confidential_reports',c],['conduct_cases',await one('select * from conduct_cases where id=$1',[k.id])]]) {
      assert.ok(Math.abs(Date.now()-row.created_at.getTime())<60000);
      await assert.rejects(db.query(`update ${name} set created_at='2000-01-01Z' where id=$1`,[row.id]),/submission time cannot be changed/);
    }
    const saved=await one('select * from conduct_cases where id=$1',[k.id]); assert.equal(saved.incident_at.getUTCFullYear(),2026);
    assert.notEqual(saved.created_at.toISOString(),saved.incident_at.toISOString());
  });
  await check('concern confidentiality and configuration writes enforce actual authenticated RLS', async () => {
    for(const role of ['caretaker','tenant','other','guardian']) {
      await actor(role);
      await assert.rejects(db.query("insert into dormitory_options(group_key,label) values('maintenance_category','Unauthorized')"));
      assert.equal((await db.query("update dormitory_options set label='Unauthorized' returning id")).rows.length,0);
      await assert.rejects(db.query('delete from dormitory_options'));
      if(['other','guardian','caretaker'].includes(role)) assert.equal((await db.query('select * from confidential_reports')).rows.length,0);
      if(['tenant','other','guardian'].includes(role)) await assert.rejects(db.query('select list_confidential_reports_v2()'));
      else assert.ok((await one('select list_confidential_reports_v2() reports')).reports.length>0);
    }
    await actor('tenant'); assert.ok((await db.query('select * from confidential_reports')).rows.length>0);
    await assert.rejects(createCase('Curfew'),/Only owners and caretakers/);
    await assert.rejects(db.query("insert into confidential_reports(tenant_id,category,summary) values($1,'safety_concern','Impersonating another tenant')",[ids.other]));
    await actor('owner'); assert.ok((await one('select list_confidential_reports_v2() reports')).reports.length>0);
  });
  await check('inactive choices are hidden from non-owners; identities and protected Other cannot change', async () => {
    await actor('owner');
    const option=await one("insert into dormitory_options(group_key,label,is_active) values('maintenance_category','Archived test',false) returning id");
    assert.ok((await db.query('select id from dormitory_options where id=$1',[option.id])).rows.length);
    await assert.rejects(db.query("update dormitory_options set code='new-identity' where id=$1",[option.id]),/identity/);
    assert.equal((await db.query("update dormitory_options set is_active=false where group_key='report_type' and code='other' returning id")).rows.length,0);
    for(const role of ['caretaker','tenant','guardian']) {
      await actor(role);
      assert.equal((await db.query('select id from dormitory_options where id=$1',[option.id])).rows.length,0);
    }
    await db.exec('reset role; set role anon');
    await assert.rejects(db.query('select * from dormitory_options'));
    await assert.rejects(db.query('select list_confidential_reports_v2()'));
  });
  await check('caretaker can create configured conduct cases; Other and future incident validation remain intact', async () => {
    await actor('caretaker');
    assert.ok((await createCase('Curfew')).id);
    await assert.rejects(createCase('Other'),/specify the conduct case category/);
    assert.ok((await one("select create_conduct_case($1,'Other','Other case','Original detailed incident',now(),'manual',null,'Specified conduct') id",[ids.tenant])).id);
    await assert.rejects(db.query("select create_conduct_case($1,'Curfew','Future case','Original incident description',now()+interval '1 day')",[ids.tenant]),/future/);
  });
  await check('escaped LIKE lookup matches literal category labels in PostgreSQL', async () => {
    await actor('owner');
    await db.query("insert into dormitory_options(group_key,label) values('maintenance_category',$1),('maintenance_category',$2)",[String.raw`100% repair_type\name`,'100abc repairXtypeZname']);
    const match=await db.query("select label from dormitory_options where group_key='maintenance_category' and label ilike $1",[String.raw`100\% repair\_type\\name`]);
    assert.deepEqual(match.rows.map(r=>r.label),[String.raw`100% repair_type\name`]);
  });
  console.log(`${passed} reporting configuration PostgreSQL checks passed.`);
} catch(error) { console.error(error); process.exitCode=1; }
finally { await db.close(); }
