// Local, isolated PostgreSQL fixtures. Never connects to Supabase.
// npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite
// node tool/test_phase3_report_room_safety.mjs
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const source = path => readFileSync(`supabase/migrations/${path}`, 'utf8');
const ids = {
  owner: '00000000-0000-0000-0000-000000000001',
  caretaker: '00000000-0000-0000-0000-000000000002',
  tenant: '00000000-0000-0000-0000-000000000003',
  guardian: '00000000-0000-0000-0000-000000000004',
};
let passed = 0;
const check = (label, fn) => fn().then(() => { passed++; console.log(`PASS ${label}`); });
async function actor(role) {
  await db.query("select set_config('test.actor', $1, false)", [ids[role] ?? '']);
}
const count = async table => (await db.query(`select count(*)::int as n from ${table}`)).rows[0].n;
async function createRoom(number, floor = 'Ground floor') {
  return (await db.query("select create_room_with_four_beds($1, $2, '') as id", [number, floor])).rows[0].id;
}
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('test.actor', true), '')::uuid $$;
    create table profiles(id uuid primary key, role text, full_name text);
    insert into profiles values ${Object.entries(ids).map(([role, id]) => `('${id}', '${role}', '${role}')`).join(',')};
    create function public.current_user_role() returns text language sql security definer set search_path = '' as $$ select role from public.profiles where id = auth.uid() $$;
    create function public.is_owner() returns boolean language sql security definer set search_path = '' as $$ select coalesce(public.current_user_role() = 'owner', false) $$;
    create function public.is_staff() returns boolean language sql security definer set search_path = '' as $$ select coalesce(public.current_user_role() in ('owner', 'caretaker'), false) $$;
    create table rooms(id uuid primary key default gen_random_uuid(), room_number text not null unique,
      floor text not null, capacity integer not null, description text default '',
      layout_number text, layout_floor text, updated_at timestamptz default now());
    create table bed_spaces(id uuid primary key default gen_random_uuid(),
      room_id uuid not null references rooms(id) on delete cascade, label text, status text default 'available', unique(room_id,label));
    create table tenant_assignments(id uuid primary key default gen_random_uuid(),
      tenant_id uuid references profiles(id), bed_space_id uuid references bed_spaces(id) on delete restrict, status text);
    create table maintenance_reports(id uuid primary key default gen_random_uuid(),
      room_id uuid references rooms(id) on delete set null, location text);
    create table room_inspections(id uuid primary key default gen_random_uuid(), room_id uuid references rooms(id) on delete restrict);
    create table room_cleaning_assignments(id uuid primary key default gen_random_uuid(), bed_space_id uuid references bed_spaces(id) on delete cascade);
    create table confidential_reports(id uuid primary key default gen_random_uuid(), tenant_id uuid references profiles(id),
      category text default 'other', summary text default 'private original', status text default 'submitted',
      response_notes text, reviewed_by uuid, reviewed_at timestamptz, created_at timestamptz default now(), updated_at timestamptz default now());
    create table confidential_report_audit(id bigint generated always as identity primary key,
      report_id uuid, actor_id uuid, action text, previous_status text, new_status text, notes text);
    create table confidential_report_addenda(id uuid primary key default gen_random_uuid(),
      report_id uuid references confidential_reports(id) on delete restrict, author_id uuid references profiles(id),
      body text, created_at timestamptz default now());
  `);
  await actor('owner');
  // Run the actual baseline structural safeguards and actual append/review RPCs.
  await db.exec(source('202610070009_room_expansion_and_dynamic_capacity.sql'));
  const identity = source('202610070011_dynamic_configuration_and_room_identity.sql');
  await db.exec(identity.slice(identity.indexOf('create or replace function public.protect_room_lifecycle()'), identity.indexOf('-- Keep historical location')));
  await db.exec(source('202610070007_confidential_addenda_idempotency.sql'));
  const review = source('202610060002_staff_report_notification_access.sql');
  await db.exec(review.slice(review.indexOf('create or replace function public.owner_review_confidential_report('), review.indexOf('revoke all on function public.owner_list_confidential_reports()')));
  // Verify upgrade with an existing room, populated four-bed structure and labels.
  const original = await createRoom('101');
  const oldBeds = (await db.query('select id from bed_spaces where room_id = $1 order by id', [original])).rows;
  await db.exec(source('202610090002_phase3_report_and_room_safety.sql'));
  await check('migration preserves room/bed IDs and four-bed structure', async () => {
    assert.deepEqual((await db.query('select id from bed_spaces where room_id = $1 order by id', [original])).rows, oldBeds);
    assert.equal((await db.query('select name from room_floors')).rows[0].name, 'Ground floor');
  });
  await check('add empty floor; reject case/whitespace duplicates', async () => {
    await db.query("select create_room_floor(' Second floor ')");
    await assert.rejects(db.query("select create_room_floor('second FLOOR')"));
    await assert.rejects(db.query("select create_room_floor(' ' )"));
    assert.equal(await count('room_floors'), 2);
  });
  await check('add room to existing floor; four beds and duplicate validation', async () => {
    const id = await createRoom('202', 'Second floor');
    assert.equal((await db.query('select count(*)::int as n from bed_spaces where room_id = $1', [id])).rows[0].n, 4);
    await assert.rejects(createRoom(' 202 '));
    await assert.rejects(createRoom('bad-floor', 'Missing floor'));
  });
  await check('room edit/move retains IDs, capacity and floor-plan identity', async () => {
    await db.query("update rooms set room_number='Renamed 101', floor='Second floor', capacity=9 where id=$1", [original]);
    const row = (await db.query('select * from rooms where id=$1', [original])).rows[0];
    assert.equal(row.capacity, 4); assert.equal(row.layout_number, '101'); assert.equal(row.layout_floor, 'Ground floor');
    assert.deepEqual((await db.query('select id from bed_spaces where room_id = $1 order by id', [original])).rows, oldBeds);
  });
  await check('direct bed delete remains blocked', async () => {
    await assert.rejects(db.query('delete from bed_spaces where id=$1', [oldBeds[0].id]));
  });
  await check('archive/reactivate allowed only without active residents', async () => {
    await db.query('update rooms set is_active=false where id=$1', [original]);
    await assert.rejects(db.query("insert into tenant_assignments(tenant_id,bed_space_id,status) values($1,$2,'active')", [ids.tenant, oldBeds[0].id]));
    await db.query('update rooms set is_active=true where id=$1', [original]);
    await db.query("insert into tenant_assignments(tenant_id,bed_space_id,status) values($1,$2,'active')", [ids.tenant, oldBeds[0].id]);
    await assert.rejects(db.query('update rooms set is_active=false where id=$1', [original]));
  });
  await check('occupied and historical assignment records block room deletion', async () => {
    await assert.rejects(db.query('select safe_delete_room($1)', [original]));
    await db.query("update tenant_assignments set status='ended'");
    await assert.rejects(db.query('delete from rooms where id=$1', [original]));
    assert.equal(await count('tenant_assignments'), 1);
  });
  await check('FK dependencies block deletion, including CASCADE and SET NULL', async () => {
    const cleaning = await createRoom('cleaning');
    await db.query('insert into room_cleaning_assignments(bed_space_id) select id from bed_spaces where room_id=$1 limit 1', [cleaning]);
    await assert.rejects(db.query('select safe_delete_room($1)', [cleaning]));
    const maintenance = await createRoom('maintenance');
    await db.query("insert into maintenance_reports(room_id,location) values($1,'other location')", [maintenance]);
    await assert.rejects(db.query('select safe_delete_room($1)', [maintenance]));
    const inspection = await createRoom('inspection');
    await db.query('insert into room_inspections(room_id) values($1)', [inspection]);
    await assert.rejects(db.query('select safe_delete_room($1)', [inspection]));
    assert.equal(await count('room_cleaning_assignments'), 1); assert.equal(await count('maintenance_reports'), 1);
  });
  await check('legacy room-label maintenance also protects history', async () => {
    const legacy = await createRoom('legacy');
    await db.query("insert into maintenance_reports(location) values('Room legacy • Bathroom')");
    await assert.rejects(db.query('select safe_delete_room($1)', [legacy]));
  });
  await check('safe room delete removes only unused structure, no cascade', async () => {
    const id = await createRoom('unused');
    await db.query('select safe_delete_room($1)', [id]);
    assert.equal((await db.query('select count(*)::int as n from bed_spaces where room_id=$1', [id])).rows[0].n, 0);
    const fk = await db.query("select confdeltype from pg_constraint where conname='bed_spaces_room_id_fkey'");
    assert.equal(fk.rows[0].confdeltype, 'r');
    assert.equal(await count('tenant_assignments'), 1);
  });
  await check('floor rename, stale-count protection and explicit merge', async () => {
    await db.query("select manage_room_floor('Second floor','Upper floor',2,false)");
    await assert.rejects(db.query("select manage_room_floor('Upper floor','Ground floor',1,true)"));
    await assert.rejects(db.query("select manage_room_floor('Upper floor','Ground floor',2,false)"));
    await db.query("select manage_room_floor('Upper floor','Ground floor',2,true)");
    assert.equal((await db.query('select floor from rooms where id=$1', [original])).rows[0].floor, 'Ground floor');
  });
  await check('dependent/archived rooms block floor deletion; empty floor deletes', async () => {
    await assert.rejects(db.query("select safe_delete_room_floor('Ground floor')"));
    await db.query("select create_room_floor('Archived floor')");
    const archived = await createRoom('archived', 'Archived floor');
    await db.query('update rooms set is_active=false where id=$1', [archived]);
    await assert.rejects(db.query("select safe_delete_room_floor('Archived floor')"));
    await db.query("select create_room_floor('Empty floor')");
    await db.query("select safe_delete_room_floor('Empty floor')");
    assert.equal((await db.query("select count(*)::int as n from room_floors where name='Empty floor'")).rows[0].n, 0);
  });
  await check('floor registry RLS permits staff reads only; direct floor writes denied', async () => {
    for (const role of ['owner', 'caretaker', 'tenant', 'guardian']) {
      await actor(role);
      await db.exec('set role authenticated');
      const visible = await count('room_floors');
      assert.equal(visible > 0, ['owner', 'caretaker'].includes(role));
      await assert.rejects(db.query("insert into room_floors values('Bypassed RPC')"));
      await db.exec('reset role');
    }
  });
  for (const role of ['caretaker', 'tenant', 'guardian', 'anonymous']) {
    await check(`${role}: room/floor mutations denied at backend`, async () => {
      await actor(role);
      await assert.rejects(createRoom('unauthorized'));
      await assert.rejects(db.query("select create_room_floor('Unauthorized')"));
      await assert.rejects(db.query("select manage_room_floor('Ground floor','Unauthorized',6,false)"));
      await assert.rejects(db.query("select safe_delete_room_floor('Ground floor')"));
      await assert.rejects(db.query('select safe_delete_room($1)', [original]));
      await assert.rejects(db.query('update rooms set description=$1 where id=$2', ['unauthorized', original]));
    });
  }
  const report = (await db.query('insert into confidential_reports(tenant_id) values($1) returning id', [ids.tenant])).rows[0].id;
  await check('caretaker review/resolve returns correct state and preserves audit', async () => {
    await actor('caretaker');
    const reviewing = await db.query("select owner_review_confidential_report($1,'under_review','Reviewing details') as report", [report]);
    assert.equal(reviewing.rows[0].report.status, 'under_review');
    await db.query("select append_confidential_report_addendum($1,'Additional details','request-123')", [report]);
    const resolved = await db.query("select owner_review_confidential_report($1,'resolved','Resolution recorded') as report", [report]);
    assert.equal(resolved.rows[0].report.status, 'resolved');
    assert.equal(await count('confidential_report_audit'), 2);
  });
  await check('resolved addenda blocked through RPC and direct inserts; retries preserve original history', async () => {
    for (const role of ['owner', 'caretaker', 'tenant', 'guardian']) {
      await actor(role);
      await assert.rejects(db.query("select append_confidential_report_addendum($1,'New additional details',$2)", [report, `request-${role}`]));
      await assert.rejects(db.query("insert into confidential_report_addenda(report_id,author_id,body,client_request_id) values($1,$2,'New addition',$3)", [report, ids[role], `direct-${role}`]));
    }
    await actor('caretaker');
    await db.query("select append_confidential_report_addendum($1,'Additional details','request-123')", [report]);
    assert.equal(await count('confidential_report_addenda'), 1);
  });
  await check('tenant/guardian reviews and invalid saves denied without false persisted state', async () => {
    for (const role of ['tenant','guardian']) {
      await actor(role);
      await assert.rejects(db.query("select owner_review_confidential_report($1,'under_review','Review notes')", [report]));
    }
    await actor('owner');
    await assert.rejects(db.query("select owner_review_confidential_report($1,'unknown','Review notes')", [report]));
    await assert.rejects(db.query("select owner_review_confidential_report($1,'under_review','bad')", [report]));
    assert.equal((await db.query('select status from confidential_reports where id=$1', [report])).rows[0].status, 'resolved');
    assert.equal(await count('confidential_report_audit'), 2);
  });
  await check('manual preflight/postflight SQL executes read-only', async () => {
    await db.exec(readFileSync('supabase/tests/phase3_floor_management_preflight.sql', 'utf8'));
  });
  console.log(`${passed} Phase 3 PostgreSQL checks passed.`);
} catch (error) {
  console.error(error.message, error.where ?? '');
  process.exitCode = 1;
} finally { await db.close(); }
