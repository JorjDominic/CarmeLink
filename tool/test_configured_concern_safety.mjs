// Isolated PostgreSQL only; no Supabase connection or production records.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
let passed = 0;
async function check(label, fn) { await fn(); passed++; console.log(`PASS ${label}`); }
try {
  await db.exec(`create role anon; create role authenticated;
    create function public.is_owner() returns boolean language sql as $$
      select current_setting('test.role',true) = 'owner' $$;
    select set_config('test.role','owner',false);
    create table maintenance_reports(id uuid primary key default gen_random_uuid(),
      category text, category_option_id uuid, location text, location_option_id uuid);
    create table confidential_reports(id uuid primary key default gen_random_uuid(),
      category text, report_type_id uuid, report_type_label text, summary text,
      specific_concern text check(specific_concern is null or char_length(btrim(specific_concern)) between 2 and 120),
      status text default 'submitted', response_notes text);`);
  const baseline = readFileSync('supabase/migrations/202610070006_dormitory_configuration_and_report_addenda.sql','utf8');
  await db.exec(baseline.slice(baseline.indexOf('create table if not exists public.dormitory_options'), baseline.indexOf('insert into public.dormitory_options')));
  await db.exec(baseline.slice(baseline.indexOf('create or replace function public.snapshot_report_options()'), baseline.indexOf('drop trigger if exists snapshot_maintenance_options')));
  await db.exec(`create trigger snapshot_concern_options before insert or update on confidential_reports
    for each row execute function public.snapshot_report_options();`);
  await db.exec(readFileSync('supabase/migrations/202610090003_configured_concern_snapshot_safety.sql','utf8'));
  let custom, report;
  await check('owner creates configurable custom type; workflow other does not require Specify', async () => {
    await db.exec('set role authenticated');
    custom = (await db.query("insert into dormitory_options(group_key,label,category_code) values('report_type','Noise concern','other') returning *")).rows[0];
    await db.exec('reset role');
    report = (await db.query("insert into confidential_reports(category,report_type_id,summary) values('other',$1,'Original details') returning *",[custom.id])).rows[0];
    assert.equal(report.report_type_label, 'Noise concern');
    assert.equal(report.specific_concern, null);
  });
  await check('rename/archive retains original report snapshot and allows review', async () => {
    await db.exec('set role authenticated');
    await db.query("update dormitory_options set label='Renamed concern', is_active=false where id=$1",[custom.id]);
    await db.exec('reset role');
    const updated = (await db.query("update confidential_reports set status='under_review',response_notes='Reviewed' where id=$1 returning *",[report.id])).rows[0];
    assert.equal(updated.report_type_label,'Noise concern');
    assert.equal(updated.summary,'Original details');
    await assert.rejects(db.query("insert into confidential_reports(category,report_type_id) values('other',$1)",[custom.id]));
  });
  await check('Other requires trimmed specification; persists through reread/review', async () => {
    const other = (await db.query("insert into dormitory_options(group_key,code,label,category_code) values('report_type','other','Other','other') returning id")).rows[0].id;
    await assert.rejects(db.query("insert into confidential_reports(category,report_type_id,specific_concern) values('other',$1,'   ')",[other]));
    const saved = (await db.query("insert into confidential_reports(category,report_type_id,specific_concern) values('other',$1,'Private specified concern') returning id",[other])).rows[0].id;
    await db.query("update confidential_reports set status='resolved' where id=$1",[saved]);
    assert.equal((await db.query('select specific_concern from confidential_reports where id=$1',[saved])).rows[0].specific_concern,'Private specified concern');
  });
  await check('switch away from Other discards irrelevant custom text', async () => {
    await db.query('update dormitory_options set is_active=true where id=$1',[custom.id]);
    const other = (await db.query("select id from dormitory_options where code='other'")).rows[0].id;
    const previous = (await db.query("insert into confidential_reports(category,report_type_id,specific_concern) values('other',$1,'Specified text') returning id",[other])).rows[0].id;
    const updated = (await db.query("update confidential_reports set report_type_id=$1 where id=$2 returning *",[custom.id,previous])).rows[0];
    assert.equal(updated.specific_concern,null);
  });
  await check('duplicate labels blocked; tenant reads active options but cannot manage them', async () => {
    await assert.rejects(db.query("insert into dormitory_options(group_key,label,category_code) values('report_type','renamed CONCERN','other')"));
    await db.exec("select set_config('test.role','tenant',false); set role authenticated;");
    await assert.rejects(db.query("insert into dormitory_options(group_key,label,category_code) values('report_type','Unauthorized','other')"));
    const rows = await db.query('select * from dormitory_options');
    assert.ok(rows.rows.every(row => row.is_active));
    await db.exec('reset role');
  });
  console.log(`${passed} configured concern PostgreSQL checks passed.`);
} catch(error) { console.error(error.message); process.exitCode=1; }
finally { await db.close(); }
