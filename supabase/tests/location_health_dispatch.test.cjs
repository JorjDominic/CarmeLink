// Run with Node and @electric-sql/pglite available via node_modules or NODE_PATH.
// pg_net/digest are test doubles: no network requests or production credentials.
const { PGlite } = require('@electric-sql/pglite');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

async function main() {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema extensions; create schema net;
    create function extensions.digest(text, text) returns bytea language sql as
      $$ select decode(repeat('ab', 32), 'hex') $$;
    create table public.guardian_alert_cron_credentials (
      token_hash text, is_active boolean default true
    );
    insert into public.guardian_alert_cron_credentials values ('existing-cron-hash', true);
    create table public.location_monitoring_incidents (
      id uuid primary key default gen_random_uuid(), tenant_id uuid default gen_random_uuid(),
      reason text default 'LOCATION_SERVICES_DISABLED', platform text default 'android',
      started_at timestamptz default now(), recovered_at timestamptz,
      escalated_at timestamptz, guardian_notified_at timestamptz
    );
    create table public.test_requests (id bigserial, url text, headers jsonb, body jsonb);
    create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds integer)
    returns bigint language plpgsql as $$ declare v_id bigint; begin
      insert into public.test_requests(url, headers, body) values (url, headers, body)
      returning id into v_id; return v_id; end $$;
  `);
  await db.exec(readFileSync(join(__dirname, '../migrations/202610050001_immediate_location_health_alerts.sql'), 'utf8'));
  const scalar = async (sql) => (await db.query(sql)).rows[0];
  const incident = await scalar('insert into public.location_monitoring_incidents default values returning id');
  const request = await scalar('select url, headers, body from public.test_requests');
  assert.equal(request.body.incident_id, incident.id, 'insert must immediately queue the reported incident');
  assert.match(request.url, /process-location-monitoring-alerts$/);
  assert.match(request.headers.Authorization, /^Bearer [a-f0-9]{64}$/);
  assert.equal((await scalar("select is_active from public.guardian_alert_cron_credentials where token_hash = 'existing-cron-hash'")).is_active, true);

  await db.exec('set role authenticated');
  await assert.rejects(db.query('select * from private.location_health_dispatch_config'), /permission denied/);
  await assert.rejects(db.query('select * from public.claim_location_monitoring_alerts()'), /permission denied/);
  await db.exec('reset role; set role service_role');
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts($1)', [incident.id])).rows.length, 1);
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts()')).rows.length, 0, 'active claim blocks competing dispatch');
  await db.exec('reset role');
  await db.query("update public.location_monitoring_incidents set dispatch_claimed_until = now() - interval '1 second' where id = $1", [incident.id]);
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts()')).rows.length, 1, 'expired claim must retry');
  await db.query('update public.location_monitoring_incidents set dispatch_claimed_until = null, guardian_notified_at = now() where id = $1', [incident.id]);
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts()')).rows.length, 0, 'successful initial alert waits for escalation');
  await db.query("update public.location_monitoring_incidents set started_at = now() - interval '31 minutes' where id = $1", [incident.id]);
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts()')).rows.length, 1, 'unresolved outage escalates');
  await db.query('update public.location_monitoring_incidents set recovered_at = now(), dispatch_claimed_until = null where id = $1', [incident.id]);
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts()')).rows.length, 0, 'recovered incidents must not alert');

  // A failing queue must preserve the outage for cron to retry.
  await db.exec(`create or replace function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds integer)
    returns bigint language plpgsql as $$ begin raise exception 'test queue unavailable'; end $$;`);
  const surviving = await scalar('insert into public.location_monitoring_incidents default values returning id');
  assert.equal((await db.query('select * from public.claim_location_monitoring_alerts($1)', [surviving.id])).rows.length, 1);
  await db.close();
  console.log('Passed: immediate trigger, private credentials, service-only claims, overlap exclusion, lease recovery, escalation, recovered filtering, queue failure fallback.');
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
