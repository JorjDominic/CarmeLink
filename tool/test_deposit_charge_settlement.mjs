// Isolated PostgreSQL tests; no connection to Supabase or real tenant data.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db = new PGlite();
const source = n => readFileSync(`supabase/migrations/${n}`, 'utf8');
const fn = (file,name) => {
  const s=source(file), start=s.indexOf(`create or replace function public.${name}(`);
  assert.ok(start>=0,name);
  return s.slice(start,s.indexOf('$$;',s.indexOf('as $$',start)+5)+3);
};
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1), tenant=id(2), caretaker=id(3), stranger=id(4);
const actor=(uid,role)=>db.query("select set_config('test.actor', $1, false),set_config('test.actor_role',$2,false)",[uid,role]);
const row=async(sql,params=[]) => (await db.query(sql,params)).rows[0];
let passed=0;
const check=async(label,f)=>{await f();passed++;console.log(`PASS ${label}`);};
const preview=async(c)=>(await row('select get_move_out_charge_preview($1) p',[c])).p;
const propose=async(c,amount=800,bill=null)=>(await row("select propose_move_out_charge_deduction($1,'damage','Damaged door',$2,'Inspection photos and repair estimate',$3) id",[c,amount,bill])).id;
const approve=d=>db.query("select review_move_out_deduction($1,true,'Repair estimate approved')",[d]);
const finish=(c,refund,total)=>db.query('select record_move_out_settlement_with_charges($1,$2,$3,$4,$5,$6,$7)',
  [c,refund,total,'Cash','refund-ref',`${c}/refund.jpg`,'Remaining damage balance is payable']);
let sequence=100;
async function makeCase(deposit=3000){
  const contract=id(sequence++), c=id(sequence++), inspect=id(sequence++), who=id(sequence++);
  await db.query("insert into profiles values($1,'Fixture tenant','tenant')",[who]);
  await db.query("insert into tenant_contracts(id,tenant_id,contract_number,status,security_deposit,created_by) values($1,$2,$3,'active',$4,$5)",[contract,who,contract,deposit,owner]);
  await db.query("insert into security_deposit_receipts(contract_id,tenant_id,received_amount,received_on) values($1,$2,$3,current_date)",[contract,who,deposit]);
  await db.query("insert into room_inspections values($1,'completed')",[inspect]);
  await db.query(`insert into move_out_cases(id,tenant_id,tenant_name_snapshot,contract_id,notice_submitted_on,
    planned_move_out_on,status,final_inspection_id,refund_due_on,created_by)
    values($1,$2,'Fixture tenant',$3,current_date,current_date+30,'settlement_pending',$4,current_date+60,$5)`,[c,who,contract,inspect,owner]);
  await db.query('insert into move_out_settlements(case_id,refund_due_on) values($1,current_date+60)',[c]);
  await db.query("insert into move_out_clearance_items(case_id,item_key,label,sort_order,status) values($1,'room_return','Room',1,'cleared')",[c]);
  await db.query("insert into storage.objects values('move_out_refund_proofs',$1)",[`${c}/refund.jpg`]);
  return {c,contract,who};
}
async function bill(contract,amount=800,category='damage',who=null){
  who ??= (await row('select tenant_id from tenant_contracts where id=$1',[contract])).tenant_id;
  return (await row(`insert into billing_charges(contract_id,tenant_id,title,category,original_amount,due_date,source,created_by)
    values($1,$2,'Damaged door',$3,$4,current_date,'staff_entry',$5) returning id`,[contract,who,category,amount,owner])).id;
}
try {
  await db.exec(`create role anon;create role authenticated;create schema auth;create schema storage;
    create type app_role as enum('owner','caretaker','tenant','guardian');
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create function public.current_user_role() returns public.app_role language sql as $$select nullif(current_setting('test.actor_role',true),'')::public.app_role$$;
    create function public.is_staff() returns boolean language sql as $$select public.current_user_role() in ('owner','caretaker')$$;
    create function public.is_guardian_of(uuid) returns boolean language sql as $$select false$$;
    create function public.set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
    create table profiles(id uuid primary key,full_name text,role app_role);
    create table guardian_tenant_links(guardian_id uuid,tenant_id uuid);
    create table tenant_contracts(id uuid primary key,tenant_id uuid,contract_number text,status text,
      security_deposit numeric,created_by uuid,starts_on date,ends_on date,monthly_rent numeric);
    create table rooms(id uuid primary key);create table room_inspections(id uuid primary key,status text);
    create table rent_charge_adjustments(charge_id uuid,amount_delta numeric);
    create table paymongo_payment_sessions(id uuid primary key default gen_random_uuid(),charge_id uuid,status text);
    create table storage.objects(bucket_id text,name text);
  `);
  await db.query("insert into profiles values($1,'Owner','owner'),($2,'Tenant','tenant'),($3,'Caretaker','caretaker'),($4,'Stranger','tenant')",[owner,tenant,caretaker,stranger]);
  const original=source('202609200001_contract_billing_synchronization.sql');
  await db.exec(original.slice(original.indexOf('create table public.billing_charges'),original.indexOf('alter table public.billing_charges')));
  await db.exec(original.slice(original.indexOf('create or replace function public.validate_payment_transaction'),original.indexOf('create or replace view public.billing_charge_summaries')));
  const actions=source('202609260001_audited_billing_actions.sql');
  const utilities=source('202609230001_separate_rent_utility_billing.sql');
  await db.exec(utilities.slice(utilities.indexOf('alter table public.billing_charges\n  drop constraint if exists billing_charges_source_check'),utilities.indexOf('-- Charges are now created')));
  await db.exec(actions.slice(0,actions.indexOf('create table public.billing_charge_actions')));
  await db.exec(actions.slice(actions.indexOf('create table public.billing_charge_actions'),actions.indexOf('-- Rent changes')));
  const move=source('20260930001500_phase8_move_out_settlement.sql');
  await db.exec(move.slice(move.indexOf('create table public.move_out_cases'),move.indexOf('alter table public.move_out_cases')));
  for(const name of ['refresh_move_out_settlement','review_move_out_deduction','record_move_out_settlement_outcome','mark_move_out_ready_for_closure'])
    await db.exec(fn('20260930001500_phase8_move_out_settlement.sql',name));
  const receipts=source('202610040002_separate_security_deposit_receipts.sql');
  await db.exec(receipts.slice(0,receipts.indexOf('-- Backfill'))+'\ncommit;');
  for(const name of ['seed_move_out_deposit_receipt','sync_finalized_deposit_receipt'])
    await db.exec(fn('202610040002_separate_security_deposit_receipts.sql',name));
  await db.exec(`create trigger seed_move_out_deposit_receipt before insert on move_out_settlements for each row execute function seed_move_out_deposit_receipt();
    create trigger sync_finalized_deposit_receipt after update of refund_status on move_out_settlements for each row execute function sync_finalized_deposit_receipt();`);
  await db.exec(source('202610090005_deposit_charge_settlement.sql'));
  await actor(owner,'owner');
  const first=await makeCase(), firstBill=await bill(first.contract);
  let deduction;
  await check('staff can propose an existing damage bill without creating a duplicate',async()=>{
    await actor(caretaker,'caretaker');deduction=await propose(first.c,800,firstBill);
    assert.equal((await row('select count(*)::int n from billing_charges')).n,1);
    await assert.rejects(approve(deduction),/Owner access required/);
    await actor(owner,'owner');
  });
  await check('unapproved and rejected damage never reduces the refundable deposit',async()=>{
    assert.equal((await preview(first.c)).settlement.refundable_amount,3000);
    const rejected=await propose(first.c,500);
    await db.query("select review_move_out_deduction($1,false,'No documented responsibility')",[rejected]);
    assert.equal((await preview(first.c)).settlement.refundable_amount,3000);
    await approve(deduction);
  });
  await check('approval previews the deduction but does not consume deposit or credit the bill',async()=>{
    const p=await preview(first.c);assert.equal(p.settlement.refundable_amount,2200);assert.equal(p.ordinary_balance,0);
    assert.equal(Number((await row('select remaining_balance from billing_charge_summaries where id=$1',[firstBill])).remaining_balance),800);
    assert.equal((await row('select count(*)::int n from billing_charge_actions')).n,0);
  });
  await check('same bill cannot be proposed twice, including in a second active case',async()=>{
    await assert.rejects(propose(first.c,800,firstBill),/already has a deposit deduction/);
    const another=await makeCase();
    await assert.rejects(propose(another.c,800,firstBill),/match this tenant, contract/);
  });
  await check('settlement credits damage exactly once and refunds only the remainder',async()=>{
    await finish(first.c,2200,800);
    const b=await row('select * from billing_charge_summaries where id=$1',[firstBill]);
    assert.equal(Number(b.remaining_balance),0);assert.equal(Number(b.deposit_applied_amount),800);
    assert.equal((await row('select original_amount from billing_charges where id=$1',[firstBill])).original_amount,'800.00');
    const r=await row('select * from security_deposit_receipts where contract_id=$1',[first.contract]);
    assert.equal(Number(r.refunded_amount),2200);assert.equal(Number(r.approved_deductions),800);
    await assert.rejects(finish(first.c,2200,800),/Finalized settlement/);
    assert.equal((await row('select count(*)::int n from billing_charge_actions where deposit_deduction_id=$1',[deduction])).n,1);
    assert.equal((await row('select count(*)::int n from payment_transactions')).n,0);
  });
  await check('damage beyond the deposit becomes a real payable balance',async()=>{
    const c=await makeCase(3000);const d=await propose(c.c,3800);await approve(d);
    await finish(c.c,0,3800);
    const item=await row('select * from move_out_deductions where id=$1',[d]);
    const b=await row('select * from billing_charge_summaries where id=$1',[item.billing_charge_id]);
    assert.equal(Number(b.remaining_balance),800);assert.equal(Number(b.deposit_applied_amount),3000);
    const r=await row('select * from security_deposit_receipts where contract_id=$1',[c.contract]);
    assert.equal(Number(r.approved_deductions),3000);
    await assert.rejects(db.query("select mark_move_out_ready_for_closure($1,'Ready')",[c.c]),/Outstanding tenant-payable/);
  });
  await check('tenant payments made before settlement reduce the deduction and prevent double charging',async()=>{
    const c=await makeCase();const b=await bill(c.contract);const d=await propose(c.c,800,b);await approve(d);
    await db.query(`insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at)
      values($1,$2,$3,200,'verified',$3,$4,now())`,[b,c.contract,c.who,owner]);
    assert.equal((await preview(c.c)).settlement.refundable_amount,2400);
    await assert.rejects(finish(c.c,2200,800),/Balances changed/);
    await finish(c.c,2400,600);
    assert.equal(Number((await row('select deposit_applied_amount from billing_charge_summaries where id=$1',[b])).deposit_applied_amount),600);
  });
  await check('ordinary rent must be cleared and is not silently deducted from the deposit',async()=>{
    const c=await makeCase();const rent=await bill(c.contract,100,'rent');const d=await propose(c.c);await approve(d);
    await assert.rejects(finish(c.c,2200,800),/Outstanding tenant-payable/);
    await assert.rejects(propose(c.c,100,rent),/match this tenant, contract/);
    assert.equal((await row('select count(*)::int n from billing_charge_actions where charge_id=$1',[rent])).n,0);
    await db.query("insert into billing_charge_actions(charge_id,action_type,amount_delta,reason,created_by) values($1,'credit',-100,'Fixture rent correction',$2)",[rent,owner]);
  });
  await check('pending payment proof blocks settlement and all credits roll back',async()=>{
    const c=await makeCase();const b=await bill(c.contract);const d=await propose(c.c,800,b);await approve(d);
    await db.query("insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by) values($1,$2,$3,100,'pending_verification',$3)",[b,c.contract,c.who]);
    await assert.rejects(finish(c.c,2200,800),/pending payments/);
    assert.equal(Number((await row('select deposit_applied_amount from move_out_deductions where id=$1',[d])).deposit_applied_amount),0);
    assert.equal((await preview(c.c)).settlement.refund_status,'pending');
    await db.query("update payment_transactions set status='rejected',reviewed_by=$2,reviewed_at=now() where charge_id=$1",[b,owner]);
  });
  await check('active gateway sessions block deposit application',async()=>{
    const c=await makeCase();const b=await bill(c.contract);const d=await propose(c.c,800,b);await approve(d);
    await db.query("insert into paymongo_payment_sessions(charge_id,status) values($1,'pending')",[b]);
    await assert.rejects(finish(c.c,2200,800),/pending payments/);
  });
  await check('increased bill balances cannot consume more than the approved amount',async()=>{
    const c=await makeCase();const b=await bill(c.contract);const d=await propose(c.c,800,b);await approve(d);
    await db.query("insert into billing_charge_actions(charge_id,action_type,amount_delta,reason,created_by) values($1,'debit',100,'New repair item',$2)",[b,owner]);
    await assert.rejects(finish(c.c,2200,800),/balance increased/);
  });
  await check('missing refund proof rolls back new bills, credits and receipt changes',async()=>{
    const c=await makeCase();const d=await propose(c.c);await approve(d);
    await db.query('delete from storage.objects where name=$1',[`${c.c}/refund.jpg`]);
    await assert.rejects(finish(c.c,2200,800),/Refund proof must belong/);
    assert.equal((await row('select billing_charge_id from move_out_deductions where id=$1',[d])).billing_charge_id,null);
    assert.equal((await preview(c.c)).settlement.refund_status,'pending');
  });
  await check('tenant, stranger and unauthenticated sessions cannot write deductions or settle',async()=>{
    for(const [uid,role] of [[tenant,'tenant'],[stranger,'tenant'],['','']]){
      await actor(uid,role);await assert.rejects(propose(first.c),/Staff access required/);
      await assert.rejects(finish(first.c,2200,800),/Owner access required/);
    }
    await actor(stranger,'tenant');await assert.rejects(preview(first.c),/Move-out access denied/);
    await actor(first.who,'tenant');assert.equal((await preview(first.c)).deductions[0].deposit_applied_amount,800);
    await actor(owner,'owner');
  });
  await check('invalid currency, another tenant bill and finalized-case proposals are rejected',async()=>{
    const c=await makeCase();
    for(const amount of ['NaN','Infinity',-1,100.001]) await assert.rejects(propose(c.c,amount),/positive amount/);
    const b=await bill(c.contract,800,'damage',stranger);await assert.rejects(propose(c.c,800,b),/match this tenant/);
    await assert.rejects(propose(first.c),/Finalized settlement/);
  });
  await check('multiple approved bills share one deposit budget without over-crediting',async()=>{
    const c=await makeCase(1000), a=await propose(c.c,800), b=await propose(c.c,800);
    await approve(a);await approve(b);await finish(c.c,0,1600);
    const totals=await row(`select sum(deposit_applied_amount) applied,
      sum(remaining_balance) payable from billing_charge_summaries where contract_id=$1`,[c.contract]);
    assert.equal(Number(totals.applied),1000);assert.equal(Number(totals.payable),600);
    assert.equal((await preview(c.c)).settlement.shortfall_amount,600);
  });
  await check('fully paid approved bills consume no deposit',async()=>{
    const c=await makeCase(), b=await bill(c.contract), d=await propose(c.c,800,b);await approve(d);
    await db.query(`insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at)
      values($1,$2,$3,800,'verified',$3,$4,now())`,[b,c.contract,c.who,owner]);
    await finish(c.c,3000,0);
    assert.equal(Number((await row('select deposit_applied_amount from move_out_deductions where id=$1',[d])).deposit_applied_amount),0);
    assert.equal((await preview(c.c)).settlement.refundable_amount,3000);
  });
  await check('exact deposit coverage and zero deposits settle without refund proof',async()=>{
    for(const deposit of [0,800]){
      const c=await makeCase(deposit),d=await propose(c.c,800);await approve(d);await finish(c.c,0,800);
      const p=await preview(c.c);
      assert.equal(p.settlement.refund_status,deposit===0?'shortfall_pending':'settled_zero');
      assert.equal(p.deductions[0].deposit_applied_amount,deposit);
    }
  });
  console.log(`${passed} deposit-to-charge PostgreSQL checks passed.`);
} catch(error){console.error(error.message,error.where??'',error.query??'');process.exitCode=1;}
finally{await db.close();}
