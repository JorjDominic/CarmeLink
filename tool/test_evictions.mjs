// Isolated PostgreSQL workflow checks. Never connects to the live database.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite(),source=f=>readFileSync(`supabase/migrations/${f}`,'utf8');
const fn=(file,name)=>{const s=source(file),i=s.indexOf(`create or replace function public.${name}(`);assert.ok(i>=0,name);return s.slice(i,s.indexOf('$$;',s.indexOf('as $$',i)+5)+3);};
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1),caretaker=id(2),stranger=id(3),guardian=id(4),hash='a'.repeat(64);
const row=async(s,p=[])=>(await db.query(s,p)).rows[0];
const actor=(uid,role)=>db.query("select set_config('test.actor',$1,false),set_config('test.role',$2,false)",[uid,role]);
let sequence=100,passed=0;
const check=async(name,f)=>{await f();passed++;console.log(`PASS ${name}`);};
const today=async()=>(await row("select (now() at time zone 'Asia/Manila')::date::text d")).d;
async function fixture(){
  const who=id(sequence++),c=id(sequence++),r=id(sequence++),b=id(sequence++),a=id(sequence++);
  await db.query("insert into profiles values($1,'Fixture tenant','tenant')",[who]);
  await db.query("insert into rooms(id,room_number,floor,capacity) values($1,$2,'1',4)",[r,r]);
  await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,'Bed A')",[b,r]);
  await db.query('insert into tenant_assignments(id,tenant_id,bed_space_id) values($1,$2,$3)',[a,who,b]);
  await db.query("insert into tenant_contracts(id,tenant_id,contract_number,status,signature_status,starts_on,ends_on,monthly_rent,security_deposit,created_by) values($1,$2,$3,'active','verified',current_date-30,current_date+365,3000,3000,$4)",[c,who,c,owner]);
  await db.query('insert into tenant_details(profile_id) values($1)',[who]);
  await db.query('insert into security_deposit_receipts(contract_id,tenant_id,received_amount,received_on) values($1,$2,3000,current_date)',[c,who]);
  return{who,c,r,b,a};
}
const decision=async(f,conduct=null)=>(await row("select record_eviction_decision($1,(now() at time zone 'Asia/Manila')::date+7,'Owner documented decision and evidence',$2) id",[f.who,conduct])).id;
const eviction=e=>row('select * from eviction_cases where id=$1',[e]);
async function publish(e){
  const path=`${e}/notices/notice.pdf`;
  await db.query("insert into storage.objects(bucket_id,name,metadata,owner_id) values('eviction-notices',$1,'{\"mimetype\":\"application/pdf\",\"size\":100}',auth.uid()::text)",[path]);
  await db.query('select publish_eviction_notice($1,$2,$3)',[e,path,hash]);return (await eviction(e)).move_out_case_id;
}
async function depart(e){await db.query("select record_eviction_departure($1,(now() at time zone 'Asia/Manila')::date,'Departure and keys confirmed')",[e]);}
async function ready(m){
  const inspection=id(sequence++);await db.query("insert into room_inspections values($1,'completed')",[inspection]);
  await db.query("update move_out_cases set final_inspection_id=$2,status='inspection_completed' where id=$1",[m,inspection]);
  await db.query("update move_out_clearance_items set status='cleared' where case_id=$1",[m]);
  return inspection;
}
async function settle(m,refund=3000,deductions=0){
  const path=`${m}/refund.jpg`;await db.query("insert into storage.objects(bucket_id,name,metadata) values('move_out_refund_proofs',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[path]);
  await db.query('select record_move_out_settlement_with_charges($1,$2,$3,$4,$5,$6,$7)',[m,refund,deductions,'Cash','Refund proof',path,'Shortfall remains payable']);
}
const close=e=>db.query("select close_eviction_case($1,'Owner verified all departure and settlement records')",[e]);
try{
  await db.exec(`create role anon;create role authenticated;create schema auth;create schema storage;
    create type app_role as enum('owner','caretaker','tenant','guardian');
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create function current_user_role() returns app_role language sql as $$select nullif(current_setting('test.role',true),'')::public.app_role$$;
    create function is_staff() returns boolean language sql as $$select public.current_user_role() in ('owner','caretaker')$$;
    create function set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=now();return new;end$$;
    create table profiles(id uuid primary key,full_name text,role app_role);
    create table tenant_contracts(id uuid primary key,tenant_id uuid,contract_number text,status text,signature_status text,
      starts_on date,ends_on date,monthly_rent numeric,security_deposit numeric,previous_contract_id uuid,created_by uuid);
    create table tenant_details(profile_id uuid primary key,residency_status text default 'active');
    create table contract_signers(contract_id uuid,signer_role text,is_required boolean);
    create table room_inspections(id uuid primary key,status text);
    create table rent_charge_adjustments(charge_id uuid,amount_delta numeric);
    create table paymongo_payment_sessions(id uuid default gen_random_uuid(),charge_id uuid,status text);
    create table conduct_cases(id uuid primary key,tenant_id uuid,status text);
    create table conduct_case_appeals(case_id uuid,status text);
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,metadata jsonb,owner_id text);
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql as $$select string_to_array($1,'/')$$;
    create function storage.filename(text) returns text language sql as $$select reverse(split_part(reverse($1),'/',1))$$;
    create table notices(title text,recipient uuid);
    create function emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$insert into public.notices values($5,$1)$$;
    create function emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$insert into public.notices values($2,null)$$;
    grant usage on schema public,auth,storage to authenticated;
    grant select,insert,delete on storage.objects to authenticated;
  `);
  const core=source('202609070002_core_dormitory_structure.sql');
  await db.exec(core.slice(0,core.indexOf('create or replace function public.set_updated_at')));
  await db.exec(`alter table rooms add column is_active boolean default true;
    create function is_guardian_of(uuid) returns boolean language sql security definer as $$select exists(
      select 1 from public.guardian_tenant_links where tenant_id=$1 and guardian_id=auth.uid())$$;`);
  for(const name of ['assign_tenant_bed','end_tenant_assignment'])await db.exec(fn('202609100002_complete_tenant_directory.sql',name));
  const billing=source('202609200001_contract_billing_synchronization.sql');
  await db.exec(billing.slice(billing.indexOf('create table public.billing_charges'),billing.indexOf('alter table public.billing_charges')));
  await db.exec(billing.slice(billing.indexOf('create or replace function public.validate_payment_transaction'),billing.indexOf('create or replace view public.billing_charge_summaries')));
  const utilities=source('202609230001_separate_rent_utility_billing.sql');
  await db.exec(utilities.slice(utilities.indexOf('alter table public.billing_charges\n  drop constraint if exists billing_charges_source_check'),utilities.indexOf('-- Charges are now created')));
  const actions=source('202609260001_audited_billing_actions.sql');
  await db.exec(actions.slice(0,actions.indexOf('-- Rent changes')));
  const move=source('20260930001500_phase8_move_out_settlement.sql');
  await db.exec(move.slice(move.indexOf('create table public.move_out_cases'),move.indexOf('alter table public.move_out_cases')));
  for(const name of ['create_move_out_case','cancel_move_out_case','refresh_move_out_settlement','review_move_out_deduction','record_move_out_settlement_outcome','mark_move_out_ready_for_closure','acknowledge_move_out_settlement'])
    await db.exec(fn('20260930001500_phase8_move_out_settlement.sql',name));
  const receipts=source('202610040002_separate_security_deposit_receipts.sql');
  await db.exec(receipts.slice(0,receipts.indexOf('-- Backfill'))+'\ncommit;');
  for(const name of ['seed_move_out_deposit_receipt','sync_finalized_deposit_receipt'])await db.exec(fn('202610040002_separate_security_deposit_receipts.sql',name));
  await db.exec(`create trigger seed_receipt before insert on move_out_settlements for each row execute function seed_move_out_deposit_receipt();
    create trigger sync_receipt after update of refund_status on move_out_settlements for each row execute function sync_finalized_deposit_receipt();`);
  await db.exec(source('202610090005_deposit_charge_settlement.sql'));
  await db.exec(source('202610090006_signed_room_transfers.sql'));
  await db.exec(source('202610090007_owner_eviction_workflow.sql'));
  await db.exec(source('202610090009_system_qa_verified_collection_totals.sql'));
  await db.exec(source('202610090010_system_qa_partial_payment_proof_visibility.sql'));
  await db.query("insert into profiles values($1,'Owner','owner'),($2,'Caretaker','caretaker'),($3,'Stranger','tenant'),($4,'Guardian','guardian')",[owner,caretaker,stranger,guardian]);
  await actor(owner,'owner');
  const f=await fixture(),e=await decision(f), original=(await row('select to_jsonb(c) s from tenant_contracts c where id=$1',[f.c])).s;
  let m,inspection;
  await check('owner decision is private, auditable and does not alter tenancy or deposit',async()=>{
    assert.equal((await row('select count(*)::int n from notices')).n,0);
    assert.equal((await row('select count(*)::int n from eviction_events')).n,1);
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.a])).status,'active');
    assert.equal(Number((await row('select received_amount from security_deposit_receipts where contract_id=$1',[f.c])).received_amount),3000);
    await assert.rejects(decision(f),/already pending/);
    await db.exec('set role authenticated');await actor(f.who,'tenant');
    assert.equal((await row('select count(*)::int n from eviction_cases')).n,0);
    await db.exec('reset role');await actor(owner,'owner');
  });
  await check('published notice creates exactly one eviction settlement with the owner deadline',async()=>{
    m=await publish(e);await db.query('select publish_eviction_notice($1,$2,$3)',[e,`${e}/notices/notice.pdf`,hash]);
    const c=await row('select * from move_out_cases where id=$1',[m]);
    assert.equal(c.case_type,'eviction');assert.equal(c.status,'notice_submitted');
    assert.equal((await row('select count(*)::int n from move_out_cases')).n,1);
    assert.equal((await row('select count(*)::int n from notices')).n,1);
    assert.equal((await row('select to_jsonb(c) s from tenant_contracts c where id=$1',[f.c])).s.status,'active');
  });
  await check('published notices are visible to the tenant and linked guardian, not strangers',async()=>{
    await db.query('insert into guardian_tenant_links(guardian_id,tenant_id) values($1,$2)',[guardian,f.who]);
    await db.exec('set role authenticated');
    for(const [uid,role,n] of [[f.who,'tenant',1],[guardian,'guardian',1],[stranger,'tenant',0]]){
      await actor(uid,role);assert.equal((await row('select count(*)::int n from eviction_cases')).n,n);
    }
    await db.exec('reset role');await actor(owner,'owner');
  });
  await check('tenant responses preserve the notice and do not finalize or consent to eviction',async()=>{
    await actor(f.who,'tenant');await db.query("select respond_to_eviction_notice($1,'I request owner review of this decision')",[e]);
    assert.equal((await eviction(e)).status,'notice_sent');
    await assert.rejects(db.query("select cancel_move_out_case($1,'Tenant cancelled')",[m]),/Only the owner/);
    await actor(owner,'owner');
  });
  await check('legacy contract and assignment actions cannot bypass pending eviction',async()=>{
    await assert.rejects(db.query("update tenant_contracts set status='terminated' where id=$1",[f.c]),/eviction workflow/);
    await assert.rejects(db.query('select end_tenant_assignment($1)',[f.who]),/eviction workflow/);
    await assert.rejects(db.query("update move_out_cases set status='cancelled' where id=$1",[m]),/Only the owner/);
    await assert.rejects(close(e),/Record actual departure/);
  });
  await check('actual departure requires evidence and a real date; it does not close the room',async()=>{
    await actor(caretaker,'caretaker');
    await assert.rejects(db.query("select record_eviction_departure($1,current_date+30,'Future')",[e]),/actual departure date/);
    await depart(e);await depart(e);await actor(owner,'owner');
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.a])).status,'active');
    await assert.rejects(close(e),/Complete inspection/);
    inspection=await ready(m);
  });
  await check('inspection and settlement are mandatory before atomic owner closure',async()=>{
    await settle(m);await close(e);await close(e);
    assert.equal((await eviction(e)).status,'closed');
    assert.equal((await row('select status from move_out_cases where id=$1',[m])).status,'closed');
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.a])).status,'ended');
    assert.equal((await row('select status from tenant_contracts where id=$1',[f.c])).status,'terminated');
    assert.equal((await row('select residency_status from tenant_details where profile_id=$1',[f.who])).residency_status,'inactive');
    const after=(await row('select to_jsonb(c) s from tenant_contracts c where id=$1',[f.c])).s;
    assert.deepEqual({...after,status:original.status},original);
    assert.equal((await row('select count(*)::int n from payment_transactions')).n,0);
  });
  await check('closed financial and inspection evidence is immutable; late acknowledgement remains possible',async()=>{
    await assert.rejects(db.query("update move_out_cases set status='settlement_completed' where id=$1",[m]),/immutable/);
    await assert.rejects(db.query('update move_out_settlements set refundable_amount=0 where case_id=$1',[m]),/immutable/);
    await assert.rejects(db.query("update room_inspections set status='cancelled' where id=$1",[inspection]),/immutable/);
    await assert.rejects(db.query('delete from storage.objects where name=$1',[`${m}/refund.jpg`]),/immutable/);
    await actor(f.who,'tenant');await db.query("select acknowledge_move_out_settlement($1,'Refund received')",[m]);
    await actor(owner,'owner');
  });
  await check('rescinding a notice preserves the contract, room and held deposit',async()=>{
    const f=await fixture(),e=await decision(f),m=await publish(e);
    await db.query("select cancel_eviction_case($1,'Owner rescinded after review')",[e]);
    assert.equal((await eviction(e)).status,'cancelled');
    assert.equal((await row('select status from move_out_cases where id=$1',[m])).status,'cancelled');
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.a])).status,'active');
    assert.equal((await row('select status from tenant_contracts where id=$1',[f.c])).status,'active');
    assert.equal((await row('select settled_at from security_deposit_receipts where contract_id=$1',[f.c])).settled_at,null);
    assert.ok(await decision(f));
  });
  await check('conduct recommendations with pending or accepted appeals cannot become eviction decisions',async()=>{
    const f=await fixture(),caseId=id(sequence++);
    await db.query("insert into conduct_cases values($1,$2,'termination_review_recommended')",[caseId,f.who]);
    await db.query("insert into conduct_case_appeals values($1,'submitted')",[caseId]);
    await assert.rejects(decision(f,caseId),/Resolve the conduct appeal/);
    await db.query("update conduct_case_appeals set status='accepted' where case_id=$1",[caseId]);
    await assert.rejects(decision(f,caseId),/Resolve the conduct appeal/);
    await db.query("update conduct_case_appeals set status='denied' where case_id=$1",[caseId]);
    assert.ok(await decision(f,caseId));
  });
  await check('caretaker, stranger and anonymous sessions cannot decide, publish, rescind or close',async()=>{
    for(const [uid,role] of [[caretaker,'caretaker'],[stranger,'tenant'],['','']]){
      await actor(uid,role);await assert.rejects(decision(f),/Owner access/);
      await assert.rejects(close(e),/Owner access/);
      await assert.rejects(db.query("select cancel_eviction_case($1,'Cancel')",[e]),/Owner access/);
      await assert.rejects(db.query('select publish_eviction_notice($1,$2,$3)',[e,`${e}/notices/notice.pdf`,hash]),/Owner access/);
    }await actor(owner,'owner');
  });
  await check('voluntary notices retain their existing 30-day validation',async()=>{
    const f=await fixture();await actor(f.who,'tenant');
    await assert.rejects(db.query("select create_move_out_case($1,current_date,current_date+7,'Voluntary')",[f.who]),/30 days/);
    await actor(owner,'owner');
  });
  await check('deposit coverage leaves a real damage shortfall that blocks closure until paid',async()=>{
    const f=await fixture(),e=await decision(f),m=await publish(e);
    await depart(e);await ready(m);
    const d=(await row("select propose_move_out_charge_deduction($1,'damage','Damaged door',3500,'Inspection and repair estimate',null) id",[m])).id;
    await db.query("select review_move_out_deduction($1,true,'Owner approved repair cost')",[d]);
    await settle(m,0,3500);
    await assert.rejects(close(e),/Outstanding tenant-payable/);
    const b=await row('select billing_charge_id from move_out_deductions where id=$1',[d]);
    assert.equal(Number((await row('select verified_amount from billing_charge_summaries where id=$1',[b.billing_charge_id])).verified_amount),0);
    await db.query(`insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at)
      values($1,$2,$3,500,'verified',$3,$4,now())`,[b.billing_charge_id,f.c,f.who,owner]);
    assert.equal(Number((await row('select verified_amount from billing_charge_summaries where id=$1',[b.billing_charge_id])).verified_amount),500);
    await close(e);
    assert.equal((await eviction(e)).status,'closed');
    assert.equal((await row('select ends_on::text d from tenant_assignments where id=$1',[f.a])).d,await today());
  });
  await check('pending gateway requests and payment proofs block closure even for future rent',async()=>{
    const f=await fixture(),e=await decision(f),m=await publish(e);
    await depart(e);await ready(m);await settle(m);
    const b=id(sequence++);
    await db.query("insert into billing_charges(id,contract_id,tenant_id,category,title,original_amount,due_date,source) values($1,$2,$3,'rent','Future rent',100,current_date+60,'manual')",[b,f.c,f.who]);
    await db.query("insert into paymongo_payment_sessions(charge_id,status) values($1,'pending')",[b]);
    await assert.rejects(close(e),/Resolve pending payment/);
    await db.query("update paymongo_payment_sessions set status='cancelled' where charge_id=$1",[b]);
    await db.query("insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by) values($1,$2,$3,100,'pending_verification',$3)",[b,f.c,f.who]);
    await assert.rejects(close(e),/Resolve pending payment/);
    await db.query("update payment_transactions set status='rejected',reviewed_by=$2,reviewed_at=now() where charge_id=$1",[b,owner]);
    await close(e);
    assert.equal((await row('select original_amount from billing_charges where id=$1',[b])).original_amount,'100.00');
  });
  await check('notice publication requires stored evidence and a currently eligible conduct recommendation',async()=>{
    const f=await fixture(),caseId=id(sequence++);
    await db.query("insert into conduct_cases values($1,$2,'termination_review_recommended')",[caseId,f.who]);
    const e=await decision(f,caseId);
    await assert.rejects(db.query('select publish_eviction_notice($1,$2,$3)',[e,`${e}/notices/missing.pdf`,hash]),/PDF/);
    await db.query("insert into conduct_case_appeals values($1,'under_review')",[caseId]);
    await assert.rejects(publish(e),/Resolve the conduct appeal/);
    assert.equal((await eviction(e)).status,'decision_recorded');
    await db.query("update conduct_case_appeals set status='denied' where case_id=$1",[caseId]);
    await db.query('delete from storage.objects where name=$1',[`${e}/notices/notice.pdf`]);
    const m=await publish(e);
    await depart(e);await ready(m);await settle(m);
    // Later changes in conduct review cannot prevent recording a completed
    // physical departure and completed financial settlement as history.
    await db.query("update conduct_cases set status='resolved' where id=$1",[caseId]);
    await close(e);
  });
  await check('authenticated users cannot directly write decisions or change registered notice evidence',async()=>{
    const f=await fixture(),e=await decision(f);await publish(e);
    await db.exec('set role authenticated');await actor(owner,'owner');
    await assert.rejects(db.query("update eviction_cases set status='closed' where id=$1",[e]),/permission denied/);
    await assert.rejects(db.query("delete from eviction_events where eviction_id=$1",[e]),/permission denied/);
    const removed=await db.query('delete from storage.objects where name=$1 returning id',[`${e}/notices/notice.pdf`]);
    assert.equal(removed.rows.length,0);
    await db.exec('reset role');await actor(owner,'owner');
  });
  await check('closed eviction history does not block a later tenancy or its room transfer',async()=>{
    const c=id(sequence++),a=id(sequence++),b=id(sequence++);
    await db.query('insert into tenant_assignments(id,tenant_id,bed_space_id) values($1,$2,$3)',[a,f.who,f.b]);
    await db.query("insert into tenant_contracts(id,tenant_id,contract_number,status,signature_status,starts_on,ends_on,monthly_rent,security_deposit,created_by) values($1,$2,$3,'active','verified',current_date,current_date+365,3500,3500,$4)",[c,f.who,c,owner]);
    await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,'Bed B')",[b,f.r]);
    const transfer=(await row("select propose_room_transfer($1,$2,current_date,'Tenant requested a new room') id",[f.who,b])).id;
    await db.query("select cancel_room_transfer($1,'Owner retained current room')",[transfer]);
    await actor(f.who,'tenant');
    const m=(await row("select create_move_out_case($1,current_date,current_date+30,'Later voluntary departure') id",[f.who])).id;
    assert.equal((await row('select contract_id from move_out_cases where id=$1',[m])).contract_id,c);
    await actor(owner,'owner');
  });
  await check('verified collection totals preserve partial cash after audited bill credits',async()=>{
    const f=await fixture(),b=id(sequence++);
    await db.query("insert into billing_charges(id,contract_id,tenant_id,category,title,original_amount,due_date,source) values($1,$2,$3,'rent','Cash total fixture',100,current_date,'manual')",[b,f.c,f.who]);
    await db.query("insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at) values($1,$2,$3,40,'verified',$3,$4,now())",[b,f.c,f.who,owner]);
    await db.query("insert into billing_charge_actions(charge_id,action_type,amount_delta,reason,created_by) values($1,'credit',-10,'Owner documented billing credit',$2)",[b,owner]);
    const summary=await row('select amount,remaining_balance,verified_amount from billing_charge_summaries where id=$1',[b]);
    assert.deepEqual(summary,{amount:'90.00',remaining_balance:'50.00',verified_amount:'40.00'});
  });
  await check('a new proof stays in owner review after earlier partial cash payment',async()=>{
    const f=await fixture(),b=id(sequence++);
    await db.query("insert into billing_charges(id,contract_id,tenant_id,category,title,original_amount,due_date,source) values($1,$2,$3,'rent','Partial proof fixture',100,current_date,'manual')",[b,f.c,f.who]);
    await db.query("insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at,submitted_at) values($1,$2,$3,40,'verified',$3,$4,now(),now()-interval '1 minute')",[b,f.c,f.who,owner]);
    await db.query("insert into payment_transactions(charge_id,contract_id,tenant_id,amount,status,submitted_by) values($1,$2,$3,20,'pending_verification',$3)",[b,f.c,f.who]);
    const summary=await row('select status,remaining_balance,verified_amount,submitted_amount from billing_charge_summaries where id=$1',[b]);
    assert.deepEqual(summary,{status:'pending_verification',remaining_balance:'60.00',verified_amount:'40.00',submitted_amount:'20.00'});
  });
  console.log(`${passed} eviction PostgreSQL checks passed.`);
}catch(e){console.error(e.message,e.where??'',e.query??'');process.exitCode=1;}
finally{await db.close();}
