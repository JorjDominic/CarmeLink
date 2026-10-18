// In-memory PostgreSQL; no remote notifications or payments.
import {PGlite} from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
const db=new PGlite();
try {
  await db.exec(`create role anon; create role authenticated; create role service_role;
    create table profiles(id uuid primary key,full_name text);
    create table paymongo_payment_sessions(id uuid primary key,status text,notification_pending boolean,
      environment text,tenant_id uuid,amount_centavos bigint,charge_id uuid,bill_breakdown jsonb);
    create table app_notifications(notification_type text,title text,body text);
    create table emitted(recipient text,title text,body text,data jsonb,event_key text);
    create function emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer) returns void language sql as
      $$insert into public.emitted values('staff',$2,$3,$6,$7)$$;
    create function emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer) returns void language sql as
      $$insert into public.emitted values('tenant+guardians',$5,$6,$9,$10)$$;
    insert into app_notifications values('payment','Test payment confirmed','TEST TRANSACTION - no real money received. Your sample bill payment was verified.');`);
  await db.exec(readFileSync('supabase/migrations/202610180003_payment_test_notification_labels.sql','utf8'));
  const old=(await db.query('select * from app_notifications')).rows[0];
  assert.equal(old.title,'Payment confirmed (TEST)'); assert.ok(old.body.endsWith('(TEST)'));
  for(const environment of ['test','live']) {
    const id=randomUUID(),tenant=randomUUID();
    await db.query("insert into profiles values($1,'Sample Tenant')",[tenant]);
    await db.query("insert into paymongo_payment_sessions values($1,'succeeded',true,$2,$3,250000,$4,'[]')",[id,environment,tenant,randomUUID()]);
    await db.query('select notify_verified_paymongo_payment($1)',[id]);
    const alerts=(await db.query('select * from emitted where event_key=$1',['paymongo-paid:'+id])).rows;
    assert.equal(alerts.length,2);
    for(const alert of alerts) {
      assert.equal(alert.title,'Payment confirmed'+(environment==='test'?' (TEST)':''));
      assert.equal(alert.body.endsWith('(TEST)'),environment==='test');
      assert.ok(alert.body.includes('2500.00')); assert.ok(alert.body.includes('Sample Tenant'));
      assert.ok(!alert.body.includes('TEST TRANSACTION')); assert.equal(alert.data.environment,environment);
    }
    await db.query('select notify_verified_paymongo_payment($1)',[id]);
    assert.equal((await db.query('select count(*)::int n from emitted where event_key=$1',['paymongo-paid:'+id])).rows[0].n,2);
    console.log(`PASS ${environment}: both sides receive the correct label, details and no duplicate alerts`);
  }
  console.log('PASS saved inbox wording normalized without resending notifications');
} finally {await db.close();}
