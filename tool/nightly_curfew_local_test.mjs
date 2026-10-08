// Runs PostgreSQL locally in-process; never contacts live Supabase.
// node tool/nightly_curfew_local_test.mjs <pglite/dist/index.js>
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const read = name => readFile(`supabase/migrations/${name}`, 'utf8');
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
try {
  await db.exec(`
    create role anon; create role authenticated; create schema private; create schema auth;
    create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
    create table public.profiles(id uuid primary key, full_name text, role text);
    create table public.tenant_details(profile_id uuid primary key, current_gate_status text, last_gate_event_at timestamptz);
    create table public.guardian_tenant_links(guardian_id uuid,tenant_id uuid);
    create table public.app_notifications(recipient_id uuid,notification_type text,title text,body text,route_type text,route_id uuid,data jsonb,created_at timestamptz default now());
    create table private.test_clock(value timestamptz);
    insert into private.test_clock values('2026-10-08 14:59:59+00');
    create table private.push_dispatches(id serial);
    create function private.dispatch_report_pushes() returns void language sql as $$ insert into private.push_dispatches default values $$;
    insert into public.profiles values('${id(1)}','Owner','owner'),('${id(2)}','Caretaker','caretaker'),
      ('${id(3)}','Guardian','guardian'),('${id(4)}','Maria','tenant'),('${id(5)}','No presence','tenant');
    insert into public.tenant_details values('${id(4)}','OUT','2026-10-08 14:00:00+00');
    insert into public.guardian_tenant_links values('${id(3)}','${id(4)}');
  `);
  const helpers = await read('202610070012_notification_coverage_completion.sql');
  await db.exec(helpers.slice(helpers.indexOf('create or replace function public.emit_app_notification'),
    helpers.indexOf('-- Contract/onboarding milestones')));
  const migration = await read('202610080007_nightly_curfew_status.sql');
  // pg_cron is hosted-only. Execute the exact worker with a controlled clock.
  const start = migration.indexOf('create or replace function private.process_nightly_curfew_status');
  const end = migration.indexOf('do $$',start);
  await db.exec(migration.slice(start,end).replaceAll('now()', '(select value from private.test_clock)'));
  const run = () => db.exec('select private.process_nightly_curfew_status()');
  const count = async () => Number((await db.query('select count(*) as n from public.app_notifications')).rows[0].n);
  await run(); assert.equal(await count(),0, 'no alerts before 11 PM Manila');
  await db.exec("update private.test_clock set value='2026-10-08 15:00:00+00'");
  await run(); assert.equal(await count(),7, 'every tenant, linked guardian and both staff receive a status');
  const notifications = (await db.query('select * from public.app_notifications')).rows;
  assert.equal(notifications.filter(n => n.data.tenant_id===id(4)).length,4);
  assert.ok(notifications.filter(n=> n.data.tenant_id===id(4)).every(n=>n.body.includes('OUT') && n.data.presence==='OUT'));
  assert.ok(notifications.filter(n=> n.data.tenant_id===id(5)).every(n=>n.data.presence==='UNAVAILABLE' && n.body.includes('unavailable')));
  assert.ok(notifications.every(n=> n.data.server_push===true && n.route_type==='gate' && n.data.curfew_date==='2026-10-08'));
  await run(); assert.equal(await count(),7, 'retry cannot duplicate nightly notifications');
  await db.exec("update public.tenant_details set current_gate_status='IN'; update private.test_clock set value='2026-10-09 15:00:00+00'");
  await run(); assert.equal(await count(),14, 'next night sends fresh status');
  const nextDay = (await db.query("select * from public.app_notifications where data->>'curfew_date'='2026-10-09' and data->>'tenant_id'=$1",[id(4)])).rows;
  assert.ok(nextDay.every(n=> n.data.presence==='IN' && n.body.includes('IN the dormitory')));
  // Verify the hosted schedule's timezone conversion too.
  assert.ok(migration.includes("'0 15 * * *'"));
  assert.equal((await db.query("select has_function_privilege('authenticated','private.process_nightly_curfew_status()','execute') as allowed")).rows[0].allowed,false);
  console.log('Nightly curfew SQL checks passed: Manila cutoff, IN/OUT/unavailable, every recipient, push queue metadata, daily deduplication, next-day refresh, restricted scheduler execution.');
} finally { await db.close(); }
