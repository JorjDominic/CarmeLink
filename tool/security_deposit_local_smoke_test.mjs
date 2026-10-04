// Local PostgreSQL smoke test; never connects to Supabase or creates live data.
// Install @electric-sql/pglite into a temporary directory, then run:
// node tool/security_deposit_local_smoke_test.mjs <absolute path to pglite/dist/index.js>
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const original = await readFile('supabase/migrations/202609200001_contract_billing_synchronization.sql', 'utf8');
const moveOut = await readFile('supabase/migrations/20260930001500_phase8_move_out_settlement.sql', 'utf8');
const actions = await readFile('supabase/migrations/202609260001_audited_billing_actions.sql', 'utf8');
const migration = await readFile('supabase/migrations/202610040002_separate_security_deposit_receipts.sql', 'utf8');
const id = (n) => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const owner = id(1), tenant = id(2), stranger = id(3), guardian = id(4);
const contract = id(10), unpaid = id(11), pending = id(12), fresh = id(13);
const scalar = async (sql) => Object.values((await db.query(sql)).rows[0])[0];
const login = async (user, role) => {
  await db.query("select set_config('request.jwt.claim.sub',$1,false), set_config('request.jwt.claim.role',$2,false)", [user, role]);
};
const fails = async (sql, message) => {
  await assert.rejects(() => db.exec(sql), message);
};

try {
  await db.exec(`
    create role authenticated; create role anon;
    create schema auth;
    grant usage on schema auth to authenticated;
    create type public.app_role as enum ('owner','caretaker','tenant','guardian');
    create function auth.uid() returns uuid language sql as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    create function public.current_user_role() returns public.app_role language sql as $$
      select current_setting('request.jwt.claim.role',true)::public.app_role $$;
    create function public.is_staff() returns boolean language sql as $$
      select public.current_user_role() in ('owner','caretaker') $$;
    create table public.guardian_tenant_links(guardian_id uuid,tenant_id uuid);
    create function public.is_guardian_of(p_tenant uuid) returns boolean language sql security definer as $$
      select exists(select 1 from public.guardian_tenant_links where guardian_id=auth.uid() and tenant_id=p_tenant) $$;
    create table public.profiles(id uuid primary key);
    insert into public.profiles values ('${owner}'),('${tenant}'),('${stranger}'),('${guardian}');
    insert into public.guardian_tenant_links values ('${guardian}','${tenant}');
    create table public.tenant_contracts(
      id uuid primary key,tenant_id uuid references public.profiles,
      contract_number text,starts_on date,ends_on date,monthly_rent numeric,
      security_deposit numeric,status text,created_by uuid references public.profiles
    );
    create table public.move_out_cases(id uuid primary key,contract_id uuid references public.tenant_contracts,tenant_id uuid,status text);
    create table public.move_out_settlements(
      case_id uuid primary key references public.move_out_cases,
      contract_deposit_amount numeric default 0,deposit_received_amount numeric default 0,
      approved_deductions numeric default 0,refundable_amount numeric default 0,
      shortfall_amount numeric default 0,refund_status text default 'pending',
      refunded_at timestamptz,updated_at timestamptz default now(),updated_by uuid
    );
    create table public.move_out_deductions(case_id uuid,amount numeric,status text);
  `);
  await db.exec(original.slice(original.indexOf('create table public.billing_charges'), original.indexOf('alter table public.billing_charges')));
  await db.exec(original.slice(original.indexOf('create or replace function public.validate_payment_transaction'), original.indexOf('create or replace view public.billing_charge_summaries')));
  await db.exec(actions.slice(actions.indexOf('create table public.billing_charge_actions'), actions.indexOf('alter table public.billing_charge_actions')));
  await db.exec(moveOut.slice(moveOut.indexOf('create or replace function public.refresh_move_out_settlement'), moveOut.indexOf('create or replace function public.create_move_out_case')));
  await db.exec(`create view public.billing_charge_summaries as
    select b.id, greatest(b.original_amount-coalesce(sum(t.amount) filter(where t.status='verified'),0),0) remaining_balance
    from public.billing_charges b left join public.payment_transactions t on t.charge_id=b.id group by b.id`);
  await login(owner, 'owner');
  for (const [c, number] of [[contract,'C1'],[unpaid,'C2'],[pending,'C3'],[fresh,'C4']]) {
    await db.query(`insert into public.tenant_contracts values($1,$2,$3,'2026-10-01','2026-12-31',3500,5000,'active',$4)`, [c, tenant, number, owner]);
  }
  for (const [b, c] of [[id(20),contract],[id(21),unpaid],[id(22),pending]]) {
    await db.query(`insert into public.billing_charges(id,contract_id,tenant_id,title,category,original_amount,due_date,created_by)
      values($1,$2,$3,'Legacy deposit','deposit',5000,'2026-10-01',$4)`, [b,c,tenant,owner]);
  }
  await db.exec(`insert into public.payment_transactions(id,charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at)
    values('${id(30)}','${id(20)}','${contract}','${tenant}',2000,'verified','${tenant}','${owner}',now());
    insert into public.payment_transactions(id,charge_id,contract_id,tenant_id,amount,status,submitted_by)
    values('${id(31)}','${id(22)}','${pending}','${tenant}',500,'pending_verification','${tenant}');`);
  await db.exec(`insert into public.billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by)
    values('${id(23)}','${tenant}','Unassigned legacy deposit','deposit',750,current_date,'${owner}');
    insert into public.payment_transactions(id,charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at)
    values('${id(32)}','${id(23)}','${tenant}',750,'verified','${tenant}','${owner}',now());`);
  await db.exec(migration);
  assert.equal(Number(await scalar(`select received_amount from public.security_deposit_receipts where contract_id='${contract}'`)),2000);
  assert.equal(Number(await scalar(`select received_amount from public.security_deposit_receipts where contract_id='${unpaid}'`)),0);
  assert.equal(await scalar(`select count(*)::int from public.billing_charge_actions where charge_id='${id(21)}' and action_type='void'`),1);
  assert.equal(await scalar('select count(*)::int from public.payment_transactions'),3);
  console.log('PASS: legacy paid evidence preserved; unpaid deposits archived; pending history retained.');
  await db.exec(`update public.payment_transactions set status='verified',reviewed_by='${owner}',reviewed_at=now() where id='${id(31)}'`);
  assert.equal(Number(await scalar(`select received_amount from public.security_deposit_receipts where contract_id='${pending}'`)),500);
  console.log('PASS: verification of an existing deposit proof updates its receipt.');
  assert.equal(await scalar(`select count(*)::int from public.get_unassigned_security_deposits('${tenant}')`),1);
  await db.exec(`select public.link_legacy_security_deposit('${id(23)}','${unpaid}')`);
  assert.equal(Number(await scalar(`select received_amount from public.security_deposit_receipts where contract_id='${unpaid}'`)),750);
  assert.equal(await scalar(`select count(*)::int from public.get_unassigned_security_deposits('${tenant}')`),0);
  assert.equal(await scalar(`select contract_id from public.billing_charges where id='${id(23)}'`),null);
  await fails(`select public.link_legacy_security_deposit('${id(23)}','${unpaid}')`,/Only an unassigned/);
  console.log('PASS: unmatched receipts can be linked once without modifying immutable history.');

  await db.exec(`select public.generate_contract_billing_charges('${fresh}')`);
  assert.equal(await scalar(`select count(*)::int from public.billing_charges where contract_id='${fresh}' and category='deposit'`),0);
  assert.equal(await scalar(`select count(*)::int from public.billing_charges where contract_id='${fresh}' and category='rent'`),3);
  await fails(`insert into public.billing_charges(tenant_id,title,category,original_amount,due_date) values('${tenant}','Deposit','deposit',5000,current_date)`,/separately/);
  await fails(`insert into public.payment_transactions(charge_id,contract_id,tenant_id,amount,submitted_by)
    values('${id(20)}','${contract}','${tenant}',500,'${tenant}')`,/outside the payment/);
  await login(tenant,'tenant');
  await fails(`select public.submit_payment_transaction('${id(20)}','Cash','ref',null,500)`,/management/);
  await fails(`select public.record_security_deposit_receipt('${contract}',5000,current_date,'Cash','R1','Receipt')`,/Owner access/);
  console.log('PASS: rent generation retained; new deposit bills and tenant deposit submissions rejected.');

  await db.exec('set role authenticated');
  assert.equal(await scalar('select count(*)::int from public.security_deposit_receipts'),4);
  await login(stranger,'tenant');
  assert.equal(await scalar('select count(*)::int from public.security_deposit_receipts'),0);
  await login(guardian,'guardian');
  assert.equal(await scalar('select count(*)::int from public.security_deposit_receipts'),4);
  await fails(`update public.security_deposit_receipts set received_amount=9000`,/permission denied/);
  await db.exec('reset role');
  await login(owner,'owner');
  await db.exec(`select public.record_security_deposit_receipt('${contract}',5000,current_date,'Cash','R1','Confirmed receipt');`);
  assert.equal(await scalar(`select count(*)::int from public.security_deposit_receipt_events where contract_id='${contract}'`),1);
  console.log('PASS: tenant/guardian isolation, direct-write denial, and owner receipt audit.');

  const caseId=id(40);
  await db.exec(`insert into public.move_out_cases values('${caseId}','${contract}','${tenant}','notice_submitted');
    insert into public.move_out_settlements(case_id) values('${caseId}');`);
  assert.equal(Number(await scalar(`select deposit_received_amount from public.move_out_settlements where case_id='${caseId}'`)),5000);
  await db.exec(`insert into public.move_out_deductions values('${caseId}',1000,'approved');
    select public.refresh_move_out_settlement('${caseId}');`);
  assert.equal(Number(await scalar(`select refundable_amount from public.move_out_settlements where case_id='${caseId}'`)),4000);
  await db.exec(`select public.record_security_deposit_receipt('${contract}',5500,current_date,'Cash','R2','Receipt correction');`);
  assert.equal(Number(await scalar(`select refundable_amount from public.move_out_settlements where case_id='${caseId}'`)),4500);
  await fails(`update public.tenant_contracts set tenant_id='${stranger}' where id='${contract}'`,/cannot be reassigned/);
  await db.exec(`update public.move_out_settlements set refund_status='refunded',refunded_at=now() where case_id='${caseId}';`);
  assert.equal(Number(await scalar(`select refunded_amount from public.security_deposit_receipts where contract_id='${contract}'`)),4500);
  await fails(`select public.record_security_deposit_receipt('${contract}',4000,current_date,'Cash','R3','Correction')`,/Finalized/);
  await fails(`delete from public.tenant_contracts where id='${contract}'`,/receipt history/);
  const zeroContract=id(50), zeroCase=id(51);
  await db.exec(`insert into public.tenant_contracts values('${zeroContract}','${tenant}','C5',current_date,current_date,3500,0,'draft','${owner}');
    insert into public.move_out_cases values('${zeroCase}','${zeroContract}','${tenant}','notice_submitted');
    insert into public.move_out_settlements(case_id) values('${zeroCase}');
    update public.move_out_settlements set refund_status='settled_zero' where case_id='${zeroCase}';`);
  assert.equal(await scalar(`select settled_at is not null from public.security_deposit_receipts where contract_id='${zeroContract}'`),true);
  console.log('PASS: move-out auto-fill, approved deductions, correction propagation, finalized refund sync, and settlement lock.');
  console.log('All local security-deposit PostgreSQL smoke checks passed.');
} finally {
  await db.close();
}
