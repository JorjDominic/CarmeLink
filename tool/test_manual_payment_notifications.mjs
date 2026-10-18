// In-memory PostgreSQL only; no network or production writes.
// node tool/test_manual_payment_notifications.mjs
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const owner = randomUUID(), caretaker = randomUUID(), tenant = randomUUID(), guardian = randomUUID();
const bill = randomUUID(), deposit = randomUUID();
const source = path => readFileSync(path, 'utf8');
let passed = 0;
const check = async (name, run) => { await run(); console.log(`PASS ${++passed}: ${name}`); };
const rows = async (sql, args = []) => (await db.query(sql, args)).rows;
const count = async (id) => (await rows("select count(*)::int n from app_notifications where data->>'transaction_id'=$1", [id]))[0].n;
async function insert(status = 'pending_verification', extras = {}) {
  const id = randomUUID();
  await db.query(`insert into payment_transactions
    (id,charge_id,tenant_id,amount,status,gateway_session_id,staff_request_id,review_notes)
    values ($1,$2,$3,250,$4,$5,$6,$7)`,
  [id, extras.charge ?? bill, tenant, status, extras.gateway ?? null, extras.staff ?? null, extras.notes ?? null]);
  return id;
}
async function assertEvent(id, event) {
  const alerts = await rows("select * from app_notifications where data->>'transaction_id'=$1 and data->>'event'=$2", [id, event]);
  assert.deepEqual(alerts.map(n => n.recipient_id).sort(), [owner, caretaker, tenant, guardian].sort());
  for (const n of alerts) {
    assert.equal(n.route_type, 'payment'); assert.equal(n.route_id, bill);
    assert.equal(n.data.payment_id, bill); assert.equal(n.data.amount, 250);
    assert.equal(n.data.server_push, true);
    assert.equal((await rows('select count(*)::int n from notification_push_jobs where notification_id=$1', [n.id]))[0].n, 1);
  }
  return alerts;
}
try {
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create function auth.uid() returns uuid language sql as
      $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key, role text, full_name text);
    create table guardian_tenant_links(guardian_id uuid, tenant_id uuid);
    create table billing_charges(id uuid primary key, category text);
    create table payment_transactions(id uuid primary key, charge_id uuid references billing_charges,
      tenant_id uuid references profiles, amount numeric(12,2), status text,
      gateway_session_id uuid, staff_request_id uuid unique, review_notes text);
    create table app_notifications(id uuid primary key default gen_random_uuid(),
      recipient_id uuid references profiles, notification_type text, title text, body text,
      route_type text, route_id uuid, data jsonb, created_at timestamptz default now());
    create table notification_push_jobs(notification_id uuid primary key references app_notifications);
  `);
  for (const [id, role] of [[owner,'owner'], [caretaker,'caretaker'], [tenant,'tenant'], [guardian,'guardian']]) {
    await db.query('insert into profiles values($1,$2,$3)', [id, role, `QA ${role}`]);
  }
  await db.query('insert into guardian_tenant_links values($1,$2),($1,$2)', [guardian,tenant]);
  await db.query("insert into billing_charges values($1,'rent'),($2,'deposit')", [bill,deposit]);
  const queue = source('supabase/migrations/202610070005_report_push_delivery.sql');
  await db.exec(queue.slice(queue.indexOf('create or replace function public.queue_server_report_push()'),
    queue.indexOf('create or replace function public.claim_report_push_jobs()')));
  await db.exec(source('supabase/migrations/202610180001_manual_payment_notifications.sql'));

  await check('submission alerts reach both sides, including the submitting tenant, and queue FCM', async () => {
    await db.query("select set_config('test.actor',$1,false)", [tenant]);
    const id = await insert(); const alerts = await assertEvent(id, 'submitted');
    assert.ok(alerts.every(n => n.body.includes('awaiting staff review')));
  });
  await check('approval and rejection notify tenant, guardians, and both staff including reviewer', async () => {
    for (const status of ['verified','rejected']) {
      const id = await insert();
      await db.query("select set_config('test.actor',$1,false)", [owner]);
      await db.query("update payment_transactions set status=$2,review_notes='Reference does not match' where id=$1", [id,status]);
      const alerts = await assertEvent(id, status); assert.equal(await count(id),8);
      if (status === 'rejected') assert.ok(alerts.every(n => n.body.includes('Reference does not match')));
      await db.query('update payment_transactions set status=status where id=$1',[id]);
      await db.query("update payment_transactions set review_notes='Later note' where id=$1",[id]);
      assert.equal(await count(id),8);
    }
  });
  await check('partial face-to-face receipts notify all recipients once per transaction', async () => {
    const request = randomUUID(); const id = await insert('verified',{staff:request});
    await assertEvent(id,'received');
    await db.query('update payment_transactions set status=status where id=$1',[id]);
    assert.equal(await count(id),4);
    await assert.rejects(() => insert('verified',{staff:request}));
    assert.equal(await count(id),4);
    await assertEvent(await insert('verified',{staff:randomUUID()}),'received');
  });
  await check('gateway, deposit, reversal, and unrelated verified imports emit no manual alerts', async () => {
    for (const id of [await insert('verified',{gateway:randomUUID()}),
      await insert('verified',{charge:deposit,staff:randomUUID()}), await insert('reversed'), await insert('verified')]) {
      assert.equal(await count(id),0);
    }
  });
  await check('rolled back payments leave no notifications or push jobs', async () => {
    const before = (await rows('select count(*)::int n from notification_push_jobs'))[0].n;
    await db.exec('begin'); const id = await insert(); await assertEvent(id,'submitted'); await db.exec('rollback');
    assert.equal(await count(id),0);
    assert.equal((await rows('select count(*)::int n from notification_push_jobs'))[0].n,before);
  });
  console.log(`${passed} manual payment notification checks passed.`);
} finally { await db.close(); }
