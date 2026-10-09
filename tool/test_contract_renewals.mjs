// Local PostgreSQL tests only; never connects to a deployed database.
// npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite
// node tool/test_contract_renewals.mjs
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';

const db = new PGlite();
const source = name => readFileSync(`supabase/migrations/${name}`, 'utf8');
const functionSql = (file, name) => {
  const sql = source(file);
  const start = sql.indexOf(`create or replace function public.${name}(`);
  assert.ok(start >= 0, `Missing ${name}`);
  const end = sql.indexOf('$$;', sql.indexOf('as $$', start) + 5);
  return sql.slice(start, end + 3);
};
const owner = '00000000-0000-0000-0000-000000000001';
const tenant = '00000000-0000-0000-0000-000000000002';
const tenant2 = '00000000-0000-0000-0000-000000000003';
const caretaker = '00000000-0000-0000-0000-000000000004';
let passed = 0;
const check = async (name, fn) => { await fn(); passed++; console.log(`PASS ${name}`); };
const actor = id => db.query("select set_config('test.actor',$1,false)", [id]);
const row = async (sql, params = []) => (await db.query(sql, params)).rows[0];
const contract = id => row('select * from tenant_contracts where id=$1', [id]);
const deposit = id => row('select * from security_deposit_receipts where contract_id=$1', [id]);
const renew = async (id, start, end, rent = 3500, notes = null) =>
  (await row('select renew_tenant_contract($1,$2,$3,$4,$5) id', [id,start,end,rent,notes])).id;
const activate = id => db.query('select activate_tenant_contract($1)', [id]);
const approve = async id => {
  await db.query("update tenant_contracts set signature_status='verified' where id=$1", [id]);
  await db.query("insert into contract_requirements values($1,true,'verified')", [id]);
  await db.query("insert into contract_signers values($1,true,'verified')", [id]);
};
const create = async (who, start, end) => {
  const c = await row(`insert into tenant_contracts(tenant_id,contract_number,starts_on,ends_on,monthly_rent,security_deposit)
    values($1,'CTR-'||gen_random_uuid(),$2,$3,3000,3000) returning *`, [who,start,end]);
  await approve(c.id);
  await activate(c.id);
  return c.id;
};

try {
  // Minimal fixtures for unrelated services. Contract protection, activation
  // checks, dates, receipt initialization and billing execute repository SQL.
  await db.exec(`
    create role anon; create role authenticated; create schema auth;
    create type public.app_role as enum('owner','caretaker','tenant','guardian');
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role app_role,full_name text,email_verified_at timestamptz);
    create function public.current_user_role() returns app_role language sql as $$ select role from public.profiles where id=auth.uid() $$;
    create function public.is_staff() returns boolean language sql as $$ select public.current_user_role() in ('owner','caretaker') $$;
    create function public.is_guardian_of(uuid) returns boolean language sql as $$ select false $$;
    create function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;
    create table tenant_details(profile_id uuid primary key,contract_starts_on date,contract_ends_on date,
      emergency_contact_name text default 'Contact',emergency_contact_phone text default '09171234567',emergency_contact_relationship text default 'Parent');
    create table contract_requirements(contract_id uuid,is_required boolean,status text);
    create table contract_signers(contract_id uuid,is_required boolean,status text);
    create table move_out_cases(id uuid primary key,contract_id uuid,status text);
    create table move_out_settlements(case_id uuid,refund_status text,deposit_received_amount numeric,updated_by uuid);
    create table payment_transactions(charge_id uuid,status text);
    create table legacy_security_deposit_links(charge_id uuid);
    create function public.refresh_move_out_settlement(uuid) returns void language sql as $$ select $$;
    create table billing_charges(id uuid primary key default gen_random_uuid(),contract_id uuid,tenant_id uuid,
      title text,category text,original_amount numeric,due_date date,period_start date,period_end date,source text,
      terms_snapshot jsonb,created_by uuid,created_at timestamptz default now());
    create unique index billing_contract_period on billing_charges(contract_id,category,period_start) where contract_id is not null;
  `);
  await db.query(`insert into profiles values($1,'owner','Owner',now()),($2,'tenant','Tenant',now()),
    ($3,'tenant','Second tenant',now()),($4,'caretaker','Caretaker',now())`, [owner,tenant,tenant2,caretaker]);
  await db.query('insert into tenant_details(profile_id) values($1),($2)', [tenant,tenant2]);
  await actor(owner);
  await db.exec(source('202609190007_contracts_crud.sql'));
  await db.exec(`alter table tenant_contracts add column signature_status text default 'not_generated';
    alter table tenant_contracts alter column contract_number set default ('CTR-'||gen_random_uuid());`);
  await db.exec(source('202609190008_contract_tenant_date_sync.sql'));
  await db.exec(functionSql('202609190010_contract_document_workflow.sql','protect_contract_after_signature'));
  await db.exec(functionSql('202609260002_onboarding_safety_gates.sql','require_verified_email_for_active_contract'));
  await db.exec(`create trigger tenant_contracts_protect_signed_terms before update on tenant_contracts
    for each row execute function protect_contract_after_signature();
    create trigger tenant_contracts_verified_activation before insert or update on tenant_contracts
    for each row execute function require_verified_email_for_active_contract();`);
  await db.exec(source('202609280007_activate_contract_without_rewriting_terms.sql'));
  const receipts = source('202610040002_separate_security_deposit_receipts.sql');
  await db.exec(receipts.slice(0,receipts.indexOf('-- Backfill')) + '\ncommit;');
  await db.exec(source('202610080002_contract_deposit_auto_receipt.sql'));
  await db.exec(functionSql('202610080006_jorge_contracts_and_staff_receipts.sql','guard_contract_price_terms'));
  await db.exec('create trigger guard_contract_price_terms before update of monthly_rent,security_deposit on tenant_contracts for each row execute function guard_contract_price_terms()');
  await db.exec(functionSql('202610040002_separate_security_deposit_receipts.sql','generate_contract_billing_charges'));
  await db.exec(functionSql('202609200001_contract_billing_synchronization.sql','sync_contract_billing_on_activation'));
  await db.exec('create trigger tenant_contracts_generate_billing after insert or update of status on tenant_contracts for each row execute function sync_contract_billing_on_activation()');
  await db.exec(source('202610090004_contract_renewals.sql'));
  const dates = await row(`select ((now() at time zone 'Asia/Manila')::date - 61)::text past,
    ((now() at time zone 'Asia/Manila')::date - 1)::text yesterday,
    ((now() at time zone 'Asia/Manila')::date)::text today,
    ((now() at time zone 'Asia/Manila')::date + 10)::text future,
    ((now() at time zone 'Asia/Manila')::date + 11)::text futureStart,
    ((now() at time zone 'Asia/Manila')::date + 365)::text nextYear`);
  const old = await create(tenant, dates.past, dates.yesterday);
  const bills = (await db.query('select * from billing_charges where contract_id=$1 order by period_start', [old])).rows;
  let next;
  await check('renewal draft preserves current contract and its issued bills', async () => {
    next = await renew(old,dates.today,dates.nextyear);
    assert.equal(Number((await contract(old)).monthly_rent),3000);
    assert.equal((await contract(old)).status,'active');
    assert.equal(Number((await contract(next)).monthly_rent),3500);
    assert.equal((await contract(next)).previous_contract_id,old);
    assert.deepEqual((await db.query('select * from billing_charges where contract_id=$1 order by period_start',[old])).rows,bills);
  });
  await check('renewal draft does not count the existing deposit twice or generate rent', async () => {
    assert.equal(Number((await deposit(old)).received_amount),3000);
    assert.equal(Number((await deposit(next)).received_amount),0);
    assert.equal((await row('select count(*)::int n from billing_charges where contract_id=$1',[next])).n,0);
  });
  await check('same save retries return the same draft', async () => assert.equal(await renew(old,dates.today,dates.nextyear),next));
  await check('changed duplicate save is rejected', async () => assert.rejects(renew(old,dates.today,dates.nextyear,4000), /already has a renewal/));
  await check('overlapping dates and invalid currency are rejected', async () => {
    await assert.rejects(renew(old,dates.yesterday,dates.nextyear), /valid renewal period/);
    for (const amount of ['NaN','Infinity',-1,3500.001]) {
      await assert.rejects(renew(old,dates.today,dates.nextyear,amount), /valid monthly rent/);
    }
  });
  await check('tenant, caretaker and unauthenticated users cannot renew or activate', async () => {
    for (const id of [tenant,caretaker,'']) {
      await actor(id);
      await assert.rejects(renew(old,dates.today,dates.nextyear), /Owner access required/);
      await assert.rejects(activate(next), /Owner access required/);
    }
    await actor(owner);
  });
  await check('signature failure rolls back previous expiration and billing', async () => {
    await assert.rejects(activate(next), /Signed contract/);
    assert.equal((await contract(old)).status,'active');
    assert.equal((await contract(next)).status,'draft');
    assert.equal((await row('select count(*)::int n from billing_charges where contract_id=$1',[next])).n,0);
  });
  await check('required documents and signers still gate renewal activation', async () => {
    await db.query("update tenant_contracts set signature_status='verified' where id=$1",[next]);
    await db.query("insert into contract_requirements values($1,true,'pending')",[next]);
    await db.query("insert into contract_signers values($1,true,'pending')",[next]);
    await assert.rejects(activate(next), /Required onboarding documents/);
    await db.query("update contract_requirements set status='verified' where contract_id=$1",[next]);
    await assert.rejects(activate(next), /Every required contract signer/);
    await db.query("update contract_signers set status='verified' where contract_id=$1",[next]);
  });
  await check('tenant signing sees the renewal while the existing contract stays active', async () => {
    await actor(tenant);
    assert.equal((await row('select get_my_contract_for_signing() c')).c.id,next);
    // Signing RPCs update signature metadata as a security definer, retaining
    // auth.uid() of the signer. The renewal guard must permit that write.
    await db.query("update tenant_contracts set signature_status='pending_verification' where id=$1",[next]);
    assert.equal((await contract(next)).signature_status,'pending_verification');
    await actor(tenant2);
    assert.equal((await row('select get_my_contract_for_signing() c')).c,null);
    await actor(owner);
    await db.query("update tenant_contracts set signature_status='verified' where id=$1",[next]);
    await assert.rejects(db.query('select get_my_contract_for_signing()'), /Tenant access required/);
  });
  await check('email and emergency contact checks still gate renewal activation', async () => {
    await db.query('update profiles set email_verified_at=null where id=$1',[tenant]);
    await assert.rejects(activate(next), /Tenant email/);
    await db.query('update profiles set email_verified_at=now() where id=$1',[tenant]);
    await db.query("update tenant_details set emergency_contact_phone='' where profile_id=$1",[tenant]);
    await assert.rejects(activate(next), /emergency contact/);
    await db.query("update tenant_details set emergency_contact_phone='09171234567' where profile_id=$1",[tenant]);
  });
  await check('move-out and settled deposits block activation and leave both contracts intact', async () => {
    await db.query("insert into move_out_cases values(gen_random_uuid(),$1,'notice_submitted')",[old]);
    await assert.rejects(activate(next), /move-out case/);
    await db.query('delete from move_out_cases where contract_id=$1',[old]);
    await db.query('update security_deposit_receipts set settled_at=now() where contract_id=$1',[old]);
    await assert.rejects(activate(next), /settled or deducted deposit/);
    assert.equal((await contract(old)).status,'active');
    assert.equal((await contract(next)).status,'draft');
    assert.equal((await row('select count(*)::int n from billing_charges where contract_id=$1',[next])).n,0);
    await db.query('update security_deposit_receipts set settled_at=null where contract_id=$1',[old]);
  });
  await check('direct writes cannot relink, overlap, create competing drafts or change rent', async () => {
    await assert.rejects(db.query('update tenant_contracts set previous_contract_id=null where id=$1',[next]), /link cannot be changed/);
    await assert.rejects(db.query('update tenant_contracts set starts_on=$2 where id=$1',[next,dates.yesterday]), /Renewal must start after/);
    await assert.rejects(db.query('update tenant_contracts set monthly_rent=4000 where id=$1',[old]), /new contract/);
    await assert.rejects(db.query(`insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent) values($1,$2,$3,3000)`,[tenant,dates.today,dates.nextyear]), /already has a renewal/);
    await assert.rejects(db.query(`update security_deposit_receipts set received_amount=3000,received_on=$2 where contract_id=$1`,[next,dates.today]), /draft cannot record/);
  });
  await check('activation expires the old term and bills the new agreed rent only for the new term', async () => {
    await activate(next);
    assert.equal((await contract(old)).status,'expired');
    assert.equal((await contract(next)).status,'active');
    const newBills = (await db.query('select * from billing_charges where contract_id=$1 order by period_start',[next])).rows;
    assert.ok(newBills.length>0);
    assert.ok(newBills.every(b => Number(b.original_amount)===3500 && b.period_start>=new Date(dates.today)));
    assert.equal(newBills[0].terms_snapshot.monthly_rent,3500);
    assert.deepEqual((await db.query('select * from billing_charges where contract_id=$1 order by period_start',[old])).rows,bills);
    assert.equal((await row('select contract_starts_on::text d from tenant_details where profile_id=$1',[tenant])).d,dates.today);
  });
  await check('deposit carryover preserves total held funds and evidence without a fake refund', async () => {
    const previous = await deposit(old); const current = await deposit(next);
    assert.equal(Number(previous.received_amount),0);
    assert.equal(previous.transferred_to_contract_id,next);
    assert.equal(Number(previous.refunded_amount),0);
    assert.equal(Number(current.received_amount),3000);
    const events = (await db.query('select reason from security_deposit_receipt_events where contract_id=$1',[next])).rows;
    assert.ok(events.some(e=>e.reason.includes('no new payment received')));
    await assert.rejects(db.query('update security_deposit_receipts set received_amount=1000 where contract_id=$1',[old]), /already transferred/);
  });
  await check('a stale move-out request cannot settle the transferred deposit again', async () => {
    await assert.rejects(db.query("insert into move_out_cases values(gen_random_uuid(),$1,'notice_submitted')",[old]), /contract was renewed/);
  });
  await check('activation retries cannot duplicate billing or deposit transfers', async () => {
    const count = (await row('select count(*)::int n from billing_charges')).n;
    await assert.rejects(activate(next), /Draft contract not found/);
    assert.equal((await row('select count(*)::int n from billing_charges')).n,count);
    assert.equal(Number((await deposit(next)).received_amount),3000);
  });
  const futureOld = await create(tenant2,dates.today,dates.future);
  const futureNext = await renew(futureOld,dates.futurestart,dates.nextyear);
  await approve(futureNext);
  await check('future renewal cannot activate or retire the current term early', async () => {
    await assert.rejects(activate(futureNext), /on or after its start date/);
    assert.equal((await contract(futureOld)).status,'active');
    assert.equal(Number((await deposit(futureOld)).received_amount),3000);
    await assert.rejects(db.query("update tenant_contracts set status='active' where id=$1",[futureNext]), /on or after its start date/);
  });
  await check('canceling a draft preserves current rent and deposit and allows a replacement', async () => {
    await db.query("update tenant_contracts set status='terminated' where id=$1",[futureNext]);
    assert.equal((await contract(futureOld)).status,'active');
    assert.equal(Number((await deposit(futureOld)).received_amount),3000);
    await renew(futureOld,dates.futurestart,dates.nextyear,3600);
  });
  await check('a renewed contract can itself have a new renewal', async () => {
    const later = await row('select ($1::date+1)::text start,($1::date+366)::text finish',[dates.nextyear]);
    const third = await renew(next,later.start,later.finish,4000);
    assert.equal((await contract(third)).previous_contract_id,next);
    assert.equal((await contract(next)).status,'active');
    // Closing a linked term must not treat its own draft successor as a conflict.
    await db.query("update tenant_contracts set status='expired' where id=$1",[next]);
    assert.equal((await contract(next)).status,'expired');
  });
  await check('linked signed history cannot be rewritten or deleted', async () => {
    await assert.rejects(db.query('update tenant_contracts set ends_on=ends_on-1 where id=$1',[old]), /original terms/);
    await assert.rejects(db.query('delete from tenant_contracts where id=$1',[old]), /foreign key/);
  });
  console.log(`${passed} contract renewal PostgreSQL checks passed.`);
} catch (error) {
  console.error(error.message, error.where ?? '', error.query ?? '');
  process.exitCode = 1;
} finally { await db.close(); }
