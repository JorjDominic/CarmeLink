// Local PostgreSQL only. Verify publication repair without changing permissions.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const migration = readFileSync('supabase/migrations/202610120003_payment_realtime_sync.sql','utf8');
try {
  await db.exec('create table billing_charge_actions(id int); create table paymongo_payment_sessions(id int); alter table billing_charge_actions enable row level security; alter table paymongo_payment_sessions enable row level security;');
  await db.exec(migration); // Environments without Realtime remain valid.
  await db.exec('create publication supabase_realtime;');
  await db.exec(migration);
  await db.exec(migration); // Reapplying never duplicates publication membership.
  const rows = (await db.query("select tablename from pg_publication_tables where pubname='supabase_realtime' order by tablename")).rows;
  assert.deepEqual(rows.map(r=>r.tablename),['billing_charge_actions','paymongo_payment_sessions']);
  assert.equal((await db.query("select count(*)::int n from pg_class where relname in ('billing_charge_actions','paymongo_payment_sessions') and relrowsecurity")).rows[0].n,2);
  console.log('Passed: publication repair, idempotency, absent publication and unchanged RLS.');
} finally { await db.close(); }
