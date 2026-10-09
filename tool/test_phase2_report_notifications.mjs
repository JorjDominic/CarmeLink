// Local only. Uses PGlite installed under ignored build/phase2_sql_tests.
// npm install --prefix build/phase2_sql_tests --ignore-scripts @electric-sql/pglite
// node tool/test_phase2_report_notifications.mjs
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite(); // In-memory PostgreSQL; no network or production connection.
const owner = '00000000-0000-0000-0000-000000000001';
const caretaker = '00000000-0000-0000-0000-000000000002';
const tenant = '00000000-0000-0000-0000-000000000003';
const guardian = '00000000-0000-0000-0000-000000000004';
const report = '00000000-0000-0000-0000-000000000010';
const room = '00000000-0000-0000-0000-000000000020';
const finding = '00000000-0000-0000-0000-000000000030';
let passed = 0;
const source = path => readFileSync(path, 'utf8');
try {
  // Minimal schema fixtures. Notification helpers and triggers below are read
  // from the real repository migrations, not reimplemented by this test.
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql as
      $$ select nullif(current_setting('test.actor', true), '')::uuid $$;
    create table profiles(id uuid primary key, role text);
    insert into profiles values ('${owner}', 'owner'), ('${caretaker}', 'caretaker'),
      ('${tenant}', 'tenant'), ('${guardian}', 'guardian');
    create table guardian_tenant_links(guardian_id uuid, tenant_id uuid);
    insert into guardian_tenant_links values ('${guardian}', '${tenant}');
    create table app_notifications(id uuid primary key default gen_random_uuid(),
      recipient_id uuid, notification_type text check(notification_type in
        ('announcement', 'payment', 'maintenance', 'curfew', 'visitor', 'gate', 'safety', 'onboarding', 'message', 'system')), title text, body text,
      route_type text, route_id uuid, data jsonb, created_at timestamptz default now(), read_at timestamptz);
    create table notification_push_jobs(notification_id uuid primary key);
    create table confidential_reports(id uuid primary key, tenant_id uuid,
      status text, response_notes text, updated_at timestamptz default now());
    create table confidential_report_addenda(id uuid primary key default gen_random_uuid(),
      report_id uuid, author_id uuid, body text, client_request_id text,
      unique(author_id, client_request_id));
    create table maintenance_reports(id uuid primary key, tenant_id uuid, status text,
      staff_notes text, description text check(length(description) >= 5),
      resolved_at timestamptz, updated_at timestamptz default now());
    create table conduct_cases(id uuid primary key, tenant_id uuid, tenant_notified_at timestamptz);
    create table conduct_case_events(id uuid primary key default gen_random_uuid(), case_id uuid, event_type text);
    create table conduct_case_appeals(id uuid primary key, case_id uuid, tenant_id uuid, status text, decision_notes text);
    create table room_inspections(id uuid primary key, room_id uuid, status text,
      summary text, notice_published_at timestamptz, updated_at timestamptz default now());
    create table room_inspection_findings(id uuid primary key, inspection_id uuid, status text,
      corrective_action text, corrected_at timestamptz, updated_at timestamptz default now());
    create table room_inspection_evidence(id uuid primary key default gen_random_uuid(), inspection_id uuid);
    create table bed_spaces(id uuid, room_id uuid);
    create table tenant_assignments(tenant_id uuid, bed_space_id uuid, status text);
    create table cleaning_noncompliance_reports(id uuid primary key, reporter_id uuid, status text, staff_notes text);
  `);
  const helpers = source('supabase/migrations/202610070012_notification_coverage_completion.sql');
  await db.exec(helpers.slice(helpers.indexOf('create or replace function public.emit_app_notification('),
    helpers.indexOf('-- Contract/onboarding milestones')));
  const queue = source('supabase/migrations/202610070005_report_push_delivery.sql');
  await db.exec(queue.slice(queue.indexOf('create or replace function public.queue_server_report_push()'),
    queue.indexOf('create or replace function public.claim_report_push_jobs()')));
  await db.exec(source('supabase/migrations/202610070003_report_alerts.sql'));
  await db.exec(source('supabase/migrations/202610090001_phase2_saved_report_notifications.sql'));
  await db.exec(`
    select set_config('test.actor', '${owner}', false);
    insert into maintenance_reports values ('${report}', '${tenant}', 'pending', '', 'original description', null, now());
    insert into confidential_reports values ('${report}', '${tenant}', 'submitted', '', now());
    insert into conduct_cases values ('${report}', '${tenant}', null);
    insert into conduct_case_appeals values ('${report}', '${report}', '${tenant}', 'submitted', '');
    insert into room_inspections values ('${report}', '${room}', 'in_progress', '', now(), now());
    insert into bed_spaces values ('${room}', '${room}');
    insert into tenant_assignments values ('${tenant}', '${room}', 'active'), ('${tenant}', '${room}', 'active');
    insert into cleaning_noncompliance_reports values ('${report}', '${tenant}', 'open', '');
  `);
  const clear = () => db.exec('truncate app_notifications, notification_push_jobs;');
  async function recipients(expected, label) {
    const rows = await db.query('select recipient_id from app_notifications order by recipient_id');
    assert.deepEqual(rows.rows.map(row => row.recipient_id), [...expected].sort(), label);
    const queued = await db.query('select count(*)::int as count from notification_push_jobs');
    assert.equal(queued.rows[0].count, expected.length, `${label}: existing push queue`);
    passed++;
    console.log(`PASS ${label}`);
  }
  await clear();
  await db.exec(`update maintenance_reports set staff_notes = 'staff saved notes' where id = '${report}'`);
  await recipients([tenant], 'maintenance notes-only save reaches tenant');
  await clear();
  await db.exec(`update maintenance_reports set staff_notes = 'staff saved notes' where id = '${report}'`);
  await recipients([], 'no-op save creates no duplicate');
  await db.exec(`select set_config('test.actor', '${tenant}', false);
    update maintenance_reports set description = 'tenant edited description' where id = '${report}'`);
  await recipients([owner, caretaker], 'tenant report edit reaches staff only');
  await clear();
  await assert.rejects(db.exec(`update maintenance_reports set description = 'bad' where id = '${report}'`));
  await recipients([], 'failed persistence creates no success notification');
  await db.exec(`begin; update maintenance_reports set description = 'rolled back description' where id = '${report}'; rollback;`);
  await recipients([], 'transaction rollback also rolls back notifications');
  await db.exec(`select set_config('test.actor', '${owner}', false);
    update maintenance_reports set status = 'in_progress', staff_notes = 'status and notes' where id = '${report}'`);
  await recipients([], 'status workflow retains one existing client producer');
  await db.exec(`select set_config('test.actor', '${tenant}', false);
    update maintenance_reports set status = 'cancelled' where id = '${report}'`);
  await recipients([owner, caretaker], 'tenant cancellation reaches staff');
  await clear();
  await db.exec(`select set_config('test.actor', '${owner}', false);`);
  await db.exec(`update confidential_reports set response_notes = 'new private review notes' where id = '${report}'`);
  await recipients([tenant], 'confidential notes-only review reaches tenant');
  await clear();
  await db.exec(`insert into confidential_report_addenda(report_id, author_id, body, client_request_id)
    values ('${report}', '${owner}', 'PRIVATE correction body', 'request-123');`);
  await recipients([caretaker, tenant], 'staff addendum excludes self and unauthorized guardian');
  const privateText = await db.query("select count(*)::int as count from app_notifications where body like '%PRIVATE%' or body like '%private review%'");
  assert.equal(privateText.rows[0].count, 0, 'no private content disclosure');
  passed++; console.log('PASS no private report text in notification payloads');
  await clear();
  await db.exec(`insert into confidential_report_addenda(report_id, author_id, body, client_request_id)
    values ('${report}', '${owner}', 'PRIVATE correction body', 'request-123') on conflict do nothing;`);
  await recipients([], 'idempotent addendum retry creates no notification duplicate');
  await db.exec(`insert into conduct_case_events(case_id, event_type) values ('${report}', 'case_created')`);
  await recipients([caretaker], 'draft conduct report remains staff-only');
  await clear();
  await db.exec(`update conduct_cases set tenant_notified_at = now() where id = '${report}';
    insert into conduct_case_events(case_id, event_type) values ('${report}', 'resolved')`);
  await recipients([caretaker, tenant], 'published conduct review reaches authorized recipients');
  await clear();
  await db.exec(`insert into conduct_case_events(case_id, event_type) values ('${report}', 'warning_issued')`);
  await recipients([], 'warning workflow does not duplicate client notification');
  await db.exec(`update conduct_case_appeals set status = 'under_review' where id = '${report}'`);
  await recipients([caretaker, tenant], 'appeal review save reaches staff and tenant');
  await clear();
  await db.exec(`insert into room_inspection_findings values ('${finding}', '${report}', 'open', 'repair item', null, now())`);
  await recipients([caretaker, tenant], 'inspection finding save deduplicates room assignments');
  await clear();
  await db.exec(`update room_inspection_findings set corrective_action = 'repair item' where id = '${finding}'`);
  await recipients([], 'unchanged inspection finding sends no duplicate');
  await db.exec(`insert into room_inspection_evidence(inspection_id) values ('${report}')`);
  await recipients([caretaker], 'inspection evidence remains staff-only');
  await clear();
  await db.exec(`update cleaning_noncompliance_reports set staff_notes = 'review notes' where id = '${report}'`);
  await recipients([tenant], 'cleaning notes-only edit keeps existing single producer');
  await clear();
  await db.exec(`update cleaning_noncompliance_reports set staff_notes = 'review notes' where id = '${report}'`);
  await recipients([], 'unchanged cleaning save produces no duplicate');

  for (const type of ['announcement', 'payment', 'maintenance', 'curfew', 'visitor', 'gate', 'safety', 'onboarding', 'message', 'system']) {
    await clear();
    await db.exec(`select set_config('test.actor', '${tenant}', false);`);
    await db.query(`select emit_staff_notification($1, 'Update', 'Saved update', $1, $2,
      '{}'::jsonb, $3, 0)`, [type, report, `all-types:${type}`]);
    await db.query(`select emit_staff_notification($1, 'Update', 'Saved update', $1, $2,
      '{}'::jsonb, $3, 0)`, [type, report, `all-types:${type}`]);
    await recipients([owner, caretaker], `${type}: existing emitter recipient and event-key dedupe`);
  }
  await clear();
  await db.exec(`select set_config('test.actor', '${owner}', false);
    insert into profiles values ('00000000-0000-0000-0000-000000000099', 'guardian');`);
  await db.query(`select emit_tenant_circle_notification($1, true, true, 'curfew',
    'Request update', 'Open request', 'curfew', $2, '{}'::jsonb, 'linked-circle', 0)`, [tenant, report]);
  await recipients([tenant, guardian], 'tenant circle excludes unrelated guardian');
  await clear();
  await db.exec(`delete from guardian_tenant_links where guardian_id = '${guardian}'`);
  await db.query(`select emit_tenant_circle_notification($1, true, true, 'curfew',
    'Request update', 'Open request', 'curfew', $2, '{}'::jsonb, 'revoked-circle', 0)`, [tenant, report]);
  await recipients([tenant], 'revoked guardian link receives no new tenant notification');

  // Execute the actual inbox RLS policy and read/unread RPCs for every role.
  const inbox = source('supabase/migrations/202609250001_fcm_notifications.sql');
  await db.exec('alter table app_notifications enable row level security; grant select on app_notifications to authenticated; grant usage on schema auth to authenticated;');
  await db.exec(inbox.slice(inbox.indexOf('create policy "users read own notifications"'), inbox.lastIndexOf('commit;')));
  const readControls = source('supabase/migrations/202609281731_phase2_notifications_and_maintenance.sql');
  await db.exec(readControls.slice(readControls.indexOf('create or replace function public.mark_all_notifications_read()'), readControls.indexOf('-- Session-driven retention')));
  for (const actor of [owner, caretaker, tenant, guardian]) {
    await clear();
    await db.exec(`select set_config('test.actor', '${actor}', false);`);
    const ids = [];
    for (const recipient of [owner, caretaker, tenant, guardian]) {
      const inserted = await db.query(`insert into app_notifications(recipient_id, title, body)
        values ('${recipient}', 'Read test', 'Update'), ('${recipient}', 'Read test', 'Update') returning id`);
      ids.push({ recipient, ids: inserted.rows.map(row => row.id) });
    }
    const own = ids.find(row => row.recipient === actor).ids;
    const other = ids.find(row => row.recipient !== actor).ids[0];
    await db.exec('set role authenticated');
    const visible = await db.query('select id from app_notifications');
    assert.equal(visible.rows.length, 2, `${actor}: RLS hides other inboxes`);
    await db.query('select mark_notification_read($1)', [other]);
    const unread = await db.query('select my_unread_notification_count() as count');
    assert.equal(unread.rows[0].count, 2, 'foreign notification read cannot affect own count');
    await db.query('select mark_notification_read($1)', [own[0]]);
    const remaining = await db.query('select my_unread_notification_count() as count');
    assert.equal(remaining.rows[0].count, 1, 'single read updates exact badge count');
    const marked = await db.query('select mark_all_notifications_read() as count');
    assert.equal(marked.rows[0].count, 1, 'Mark All affects remaining own rows');
    const repeat = await db.query('select mark_all_notifications_read() as count');
    assert.equal(repeat.rows[0].count, 0, 'Mark All is idempotent');
    await db.exec('reset role');
    const foreignUnread = await db.query(`select count(*)::int as count from app_notifications where recipient_id <> '${actor}' and read_at is null`);
    assert.equal(foreignUnread.rows[0].count, 6, 'other roles remain unread');
    passed++; console.log(`PASS ${actor}: inbox RLS, single read, Mark All, badge count, idempotency`);
  }
  await db.exec("select set_config('test.actor', '', false)");
  await assert.rejects(db.query('select mark_all_notifications_read()'));
  passed++; console.log('PASS unauthenticated Mark All denied');
  console.log(`${passed} PostgreSQL notification checks passed.`);
} finally {
  await db.close();
}
