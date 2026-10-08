// Runs PostgreSQL in-process; never connects to live Supabase.
// node tool/staff_payment_local_smoke_test.mjs <pglite/dist/index.js>
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const read = async (name) => (await readFile(`supabase/migrations/${name}`, 'utf8')).replaceAll('\r\n','\n');
const original = await read('202609200001_contract_billing_synchronization.sql');
const actions = await read('202609260001_audited_billing_actions.sql');
const config = await read('202610070011_dynamic_configuration_and_room_identity.sql');
const migration = await read('202610080001_staff_received_payments.sql');
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1), caretaker=id(2), tenant=id(3), bill=id(10);
const login = (user,role) => db.query(
  "select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.role',$2,false)", [user,role]);
const scalar = async sql => Object.values((await db.query(sql)).rows[0])[0];
const record = (request,amount,extra={}) => db.query(
  'select public.record_staff_payment($1,$2,$3,$4,$5,$6,$7,$8) as result',
  [id(request),extra.bill??bill,amount,extra.method??'cash',extra.date??'2026-01-01',
   'R-001',extra.photo??`cloudinary://authenticated/${extra.actor??owner}/payment/${extra.bill??bill}/photo.jpg`,'Counter payment']);
try {
  await db.exec(`
    create role authenticated; create role anon; create role service_role; create schema auth;
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function auth.role() returns text language sql as $$
      select case when current_setting('request.jwt.claim.role',true)='service_role'
        then 'service_role' else 'authenticated' end $$;
    create function public.current_user_role() returns text language sql as $$
      select current_setting('request.jwt.claim.role',true) $$;
    create function public.is_staff() returns boolean language sql as $$
      select public.current_user_role() in ('owner','caretaker') $$;
    create table public.profiles(id uuid primary key,full_name text);
    insert into public.profiles values('${owner}','Owner'),('${caretaker}','Caretaker'),('${tenant}','Tenant');
    create table public.tenant_contracts(id uuid primary key);
  `);
  await db.exec(original.slice(original.indexOf('create table public.billing_charges'),
    original.indexOf('alter table public.billing_charges enable row level security')));
  await db.exec(`alter table public.billing_charges add column notes text;
    create table public.rent_charge_adjustments(charge_id uuid,amount_delta numeric);
    create table public.billing_charge_actions(charge_id uuid,action_type text,amount_delta numeric,new_due_date date,created_at timestamptz default now());
    create table public.dormitory_options(group_key text,code text,label text,is_active boolean);
    insert into public.dormitory_options values('payment_method','cash','Cash',true);
    insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
      values('${bill}','${tenant}','Rent','rent',4000,current_date,'${owner}');`);
  const viewStart=actions.indexOf('create or replace view public.billing_charge_summaries');
  await db.exec(actions.slice(viewStart,actions.indexOf('grant select on public.billing_charge_summaries',viewStart)));
  const methodStart=config.indexOf('create or replace function public.validate_configured_payment_method');
  const methodEnd=config.indexOf('create trigger validate_configured_payment_method before insert or update of payment_method\non public.payments',methodStart);
  await db.exec(config.slice(methodStart,methodEnd));
  await db.exec('alter table public.payment_transactions drop constraint payment_transactions_payment_method_check');
  await db.exec(migration);
  await login(tenant,'tenant');
  await assert.rejects(()=>record(100,500),/Owner or caretaker/);
  await login(owner,'owner');
  for(const amount of [0,-1,4001,0.001]) await assert.rejects(()=>record(100,amount),/positive amount/);
  await assert.rejects(()=>record(100,500,{photo:''}),/receipt photo/);
  await assert.rejects(()=>record(100,500,{photo:`cloudinary://authenticated/${tenant}/payment/${bill}/photo.jpg`}),/receipt photo/);
  await assert.rejects(()=>record(100,500,{date:'2099-01-01'}),/future/);
  await assert.rejects(()=>record(100,500,{method:'nonexistent'}),/active payment method/);
  let result=(await record(100,1500)).rows[0].result;
  assert.equal(result.payment.remaining_balance,2500);
  assert.equal(result.payment.status,'partially_paid');
  assert.equal(result.is_new,true);
  result=(await record(100,1500)).rows[0].result;
  assert.equal(result.is_new,false);
  assert.equal(await scalar('select count(*) from public.payment_transactions'),1);
  await assert.rejects(()=>record(100,1000),/different details/);
  await db.exec(`insert into public.payment_transactions(charge_id,tenant_id,amount,submitted_by)
    values('${bill}','${tenant}',100,'${tenant}')`);
  await assert.rejects(()=>record(101,500),/pending payment proof/);
  await db.exec(`update public.payment_transactions set status='rejected',reviewed_by='${owner}',reviewed_at=now()
    where status='pending_verification'`);
  await login(caretaker,'caretaker');
  await assert.rejects(()=>record(100,1500,{actor:caretaker}),/different details/);
  result=(await record(101,2500,{actor:caretaker})).rows[0].result;
  assert.equal(result.payment.remaining_balance,0);
  assert.equal(result.payment.status,'verified');
  assert.equal(await scalar(`select reviewed_by::text from public.payment_transactions where staff_request_id='${id(101)}'`),caretaker);
  await assert.rejects(()=>record(102,1,{actor:caretaker}),/already paid/);
  await db.exec(`insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
    values('${id(11)}','${tenant}','Voided','other',100,current_date,'${owner}'),
    ('${id(12)}','${tenant}','Deposit','deposit',100,current_date,'${owner}');
    insert into public.billing_charge_actions(charge_id,action_type) values('${id(11)}','void')`);
  await assert.rejects(()=>record(103,50,{bill:id(11),actor:caretaker}),/voided/);
  await assert.rejects(()=>record(104,50,{bill:id(12),actor:caretaker}),/deposits separately/);
  await db.exec(`insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
    values('${id(14)}','${tenant}','Submission test','rent',100,current_date,'${owner}')`);
  await login(tenant,'tenant');
  await db.query('select public.submit_payment_transaction($1,$2,$3,$4,$5)',[id(14),'cash','T-001',null,40]);
  await login(owner,'owner');
  await assert.rejects(()=>record(105,10,{bill:id(14)}),/pending payment proof/);
  await db.query('select public.review_payment_transaction($1,$2,$3)',[id(14),true,'Received']);
  assert.equal(Number(await scalar(`select remaining_balance from public.billing_charge_summaries where id='${id(14)}'`)),60);
  await db.exec(`insert into public.payment_transactions(charge_id,tenant_id,amount,submitted_by)
    values('${id(14)}','${tenant}',61,'${tenant}')`);
  await assert.rejects(()=>db.query('select public.review_payment_transaction($1,$2,$3)',[id(14),true,'Received']),/exceeds the current/);
  console.log('Staff payment SQL checks passed: permissions, receipt scope, validation, partial/full payment, retry deduplication, pending proof, void and deposit guards.');
  await db.exec(`alter table public.profiles add column role text;
    update public.profiles set role=case id when '${owner}' then 'owner' when '${caretaker}' then 'caretaker' else 'tenant' end;
    create function public.emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$ select $$;
    create function public.emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$ select $$;`);
  await db.exec(await read('202610080003_owner_payment_mode.sql'));
  await db.exec(await read('202610080004_paymongo_qr_payments.sql'));
  await login(owner,'owner');
  await assert.rejects(()=>db.query("select public.set_payment_collection_mode('paymongo')"),/not connected/);
  await login(caretaker,'caretaker');
  await assert.rejects(()=>db.query("select public.set_payment_collection_mode('manual')"),/Only the owner/);
  await db.exec(`insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
    values('${id(50)}','${tenant}','Gateway test','rent',1200,current_date,'${owner}');
    update public.payment_collection_settings set paymongo_ready=true;`);
  await login(owner,'owner');
  await db.query("select public.set_payment_collection_mode('paymongo')");
  await login(tenant,'tenant');
  let started=(await db.query('select public.begin_paymongo_payment($1) as value',[id(50)])).rows[0].value;
  const testSession=started.session.id;
  assert.equal(started.session.amount_centavos,120000);
  assert.equal(started.is_new,true);
  started=(await db.query('select public.begin_paymongo_payment($1) as value',[id(50)])).rows[0].value;
  assert.equal(started.is_new,false);
  assert.equal(started.session.id,testSession);
  await db.exec(`update public.paymongo_payment_sessions set provider_intent_id='pi_Test',status='pending' where id='${testSession}'`);
  const settle=(session,intent,payment,amount=120000,environment='test')=>db.query(
    'select public.settle_paymongo_payment($1,$2,$3,$4,$5,$6,$7) as session',
    [session,intent,payment,amount,'PHP',environment,'2026-10-08T00:00:00Z']);
  await db.exec('set role authenticated');
  await assert.rejects(()=>settle(testSession,'pi_Test','pay_Test'),/permission denied/);
  await assert.rejects(()=>db.exec('update public.paymongo_payment_sessions set amount_centavos=100'),/permission denied/);
  await db.exec('reset role');
  await login('', 'service_role');
  await assert.rejects(()=>settle(testSession,'pi_Test','pay_Test',119999),/does not match/);
  const countBefore=await scalar('select count(*) from public.payment_transactions');
  const testConfirmed=(await settle(testSession,'pi_Test','pay_Test')).rows[0].session;
  assert.equal(testConfirmed.status,'succeeded');
  assert.equal(testConfirmed.credited_transaction_id,null);
  assert.equal(await scalar('select count(*) from public.payment_transactions'),countBefore);
  assert.equal(Number(await scalar(`select remaining_balance from public.billing_charge_summaries where id='${id(50)}'`)),1200);
  await settle(testSession,'pi_Test','pay_Test');
  await assert.rejects(()=>settle(testSession,'pi_Test','pay_Conflict'),/conflict/);
  await db.exec("update public.payment_collection_settings set environment='live'");
  await login(tenant,'tenant');
  const liveSession=(await db.query('select public.begin_paymongo_payment($1) as value',[id(50)])).rows[0].value.session.id;
  await db.exec(`update public.paymongo_payment_sessions set provider_intent_id='pi_Live',status='pending' where id='${liveSession}'`);
  await login(owner,'owner');
  await assert.rejects(()=>record(500,100,{bill:id(50)}),/automatic payment is still active/);
  await db.query("select public.set_payment_collection_mode('manual')");
  await login('', 'service_role');
  const liveConfirmed=(await settle(liveSession,'pi_Live','pay_Live',120000,'live')).rows[0].session;
  assert.equal(liveConfirmed.status,'succeeded');
  assert.ok(liveConfirmed.credited_transaction_id);
  await settle(liveSession,'pi_Live','pay_Live',120000,'live');
  assert.equal(await scalar('select count(*) from public.payment_transactions'),countBefore+1);
  assert.equal(Number(await scalar(`select remaining_balance from public.billing_charge_summaries where id='${id(50)}'`)),0);
  await login(owner,'owner');
  await assert.rejects(()=>db.exec(`update public.payment_transactions set status='rejected' where gateway_session_id='${liveSession}'`),/backend access/);
  await db.exec(`insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
    values('${id(51)}','${tenant}','Conflict test','rent',1000,current_date,'${owner}');`);
  await db.query("select public.set_payment_collection_mode('paymongo')");
  await login(tenant,'tenant');
  await assert.rejects(()=>db.query('select public.submit_payment_transaction($1,$2,$3,$4,$5)',[id(51),'cash','R',null,100]),/Receipt submission is disabled/);
  const conflictSession=(await db.query('select public.begin_paymongo_payment($1) as value',[id(51)])).rows[0].value.session.id;
  await db.exec(`update public.paymongo_payment_sessions set provider_intent_id='pi_Conflict',status='pending' where id='${conflictSession}';
    insert into public.billing_charge_actions(charge_id,action_type) values('${id(51)}','void');`);
  await login('', 'service_role');
  const conflict=(await settle(conflictSession,'pi_Conflict','pay_Received',100000,'live')).rows[0].session;
  assert.equal(conflict.status,'needs_review');
  assert.equal(conflict.credited_transaction_id,null);
  await db.exec(`update public.paymongo_payment_sessions set last_checked_at=now()-interval '10 minutes' where id='${conflictSession}'`);
  const claimed=(await db.query('select * from public.claim_paymongo_reconciliation()')).rows;
  assert.equal(claimed.length,1);
  assert.equal(claimed[0].id,conflictSession);
  assert.equal((await db.query('select * from public.claim_paymongo_reconciliation()')).rows.length,0);
  await login(owner,'owner');
  await db.exec('set role authenticated');
  await assert.rejects(()=>db.query('select * from public.claim_paymongo_reconciliation()'),/permission denied/);
  await db.exec('reset role');
  await login(caretaker,'guardian');
  await db.exec('set role authenticated');
  assert.equal((await db.query('select * from public.paymongo_payment_sessions')).rows.length,0);
  await db.exec('reset role');
  await login(tenant,'tenant');
  await db.exec('set role authenticated');
  assert.equal((await db.query('select * from public.paymongo_payment_sessions')).rows.length,3);
  await db.exec('reset role');
  console.log('PayMongo SQL checks passed: owner-only switch, readiness, bill amount, request reuse, backend-only settlement, sandbox isolation, duplicate callbacks, mode switching, staff conflicts and reconciliation.');
} catch(error) { console.error(error.message); process.exitCode=1; } finally { await db.close(); }
