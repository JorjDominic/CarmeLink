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
    create role authenticated; create role anon; create schema auth;
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
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
} catch(error) { console.error(error.message); process.exitCode=1; } finally { await db.close(); }
