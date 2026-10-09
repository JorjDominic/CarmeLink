// Isolated PostgreSQL; no production access or notification delivery.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
let passed = 0;
const check = async (name, run) => { await run(); passed++; console.log(`PASS ${name}`); };
const actor = role => db.query("select set_config('test.role',$1,false)", [role]);
const row = async () => (await db.query('select * from dorm_boundary_config')).rows[0];
const update = params => db.query('select update_dorm_boundary_config($1,$2,$3,$4,$5,$6)', params);
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create function auth.uid() returns uuid language sql as $$select '00000000-0000-0000-0000-000000000001'::uuid$$;
    create table profiles(id uuid primary key,role text);
    insert into profiles values(auth.uid(),'owner');
    create function is_staff() returns boolean language sql as $$select role in ('owner','caretaker') from profiles where id=auth.uid()$$;
    create table gate_events(id int primary key);
    insert into gate_events values(1);
    alter table gate_events enable row level security;
    grant usage on schema public,auth to anon,authenticated;
    grant select on gate_events to anon,authenticated;
    create policy "Allow anon to read gate_events" on gate_events for select to anon using(true);
    create policy staff_read on gate_events for select to authenticated using(is_staff());`);
  await db.exec(readFileSync('supabase/migrations/202609180002_dorm_boundary_polygon.sql','utf8'));
  await db.exec('alter table dorm_boundary_config add column config_version bigint not null default 1');
  const before = await row();
  await db.exec(readFileSync('supabase/migrations/202610090008_system_qa_boundary_and_gate_access.sql','utf8'));
  await check('repair installation preserves the saved boundary and gate history', async () => {
    assert.deepEqual(await row(), before);
    assert.equal((await db.query('select count(*)::int n from gate_events')).rows[0].n,1);
  });
  await check('anonymous gate-history access is denied', async () => {
    await db.exec('set role anon');
    await assert.rejects(db.query('select * from gate_events'),/permission denied/);
    await assert.rejects(update([null,null,null,null,null,null]),/permission denied/);
    await db.exec('reset role');
  });
  await check('tenant and guardian cannot change boundary configuration', async () => {
    for (const role of ['tenant','guardian']) {
      await db.query('update profiles set role=$1',[role]);
      await assert.rejects(update([14,120,50,3,'circle',null]),/Unauthorized/);
    }
    await db.exec("update profiles set role='owner'");
    assert.deepEqual(await row(),before);
  });
  await check('invalid coordinates, radius and buffers cannot corrupt the active boundary', async () => {
    for (const params of [[91,null,null,null,null,null],[null,181,null,null,null,null],
      [null,null,0,null,null,null],[null,null,'Infinity',null,null,null],
      [null,null,null,-1,null,null],[null,null,null,'NaN',null,null]]) {
      await assert.rejects(update(params),/Invalid/);
    }
    assert.deepEqual(await row(),before);
  });
  await check('malformed, incomplete, repeated or out-of-range polygon vertices are rejected', async () => {
    for (const points of ['oops','{}','[]','[{"lat":1,"lng":2}]',
      '[{"lat":1,"lng":2},{"lat":1,"lng":2},{"lat":1,"lng":2}]',
      '[{"lat":1,"lng":2},{"lat":2,"lng":3},{"lat":200,"lng":4}]',
      '[{"lat":1,"lng":2},{"lat":2,"lng":3},{"lat":"3","lng":4}]']) {
      await assert.rejects(update([null,null,null,null,null,points]),/Invalid polygon|Polygon/);
    }
    assert.deepEqual(await row(),before);
  });
  await check('owner partial updates preserve omitted geometry and increment its version', async () => {
    await update([null,null,60,null,null,null]);
    const after=await row();
    assert.equal(after.radius_meters,60);
    assert.equal(after.config_version,2);
    assert.deepEqual(after.polygon_points,before.polygon_points);
    assert.equal(after.center_latitude,before.center_latitude);
  });
  await check('caretaker can save valid boundary geometry', async () => {
    await db.exec("update profiles set role='caretaker'");
    const points=[{lat:14,lng:120},{lat:14.001,lng:120},{lat:14,lng:120.001}];
    await update([14,120,50,3,'polygon',JSON.stringify(points)]);
    assert.deepEqual((await row()).polygon_points,points);
    assert.equal((await row()).config_version,3);
  });
  console.log(`${passed} system QA repair PostgreSQL checks passed.`);
} finally { await db.close(); }
