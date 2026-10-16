// Disposable PostgreSQL only. Optional --disposable --local-config <private loopback config>.
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {bootstrapFinancialIntegrity,applyFinancialIntegrity} from './financial_integrity_fixture.mjs';
import {owner,tenant,otherTenant,caretaker} from './paymongo_phase1_fixture.mjs';
let db;const at=process.argv.indexOf('--local-config');
if(at>=0) {
 assert.ok(process.argv.includes('--disposable'));const config=JSON.parse(readFileSync(process.argv[at+1],'utf8'));
 const url=new URL(config.connectionString);assert.ok(['127.0.0.1','localhost','[::1]'].includes(url.hostname));
 assert.match(url.pathname,/^\/carmelink_financial_validation_[a-z0-9_]+$/);
 const {default:pg}=await import('../build/phase2_sql_tests/node_modules/pg/lib/index.js');const c=new pg.Client(config);await c.connect();
 assert.equal(Number((await c.query("select count(*) n from pg_tables where schemaname='public'")).rows[0].n),0,'Refusing nonempty database');
 db={query:(sql,args)=>c.query(sql,args),exec:sql=>c.query(sql),close:()=>c.end()};
} else {const {PGlite}=await import('../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js');db=new PGlite();}
let passed=0;const one=async(sql,args=[])=>(await db.query(sql,args)).rows[0];
const scalar=async(sql,args=[])=>Object.values(await one(sql,args))[0];
const root=()=>db.exec('reset role');
async function actor(who=owner,backend=false){await root();await db.query("select set_config('test.actor',$1,false),set_config('test.jwtrole',$2,false)",[who,backend?'service_role':'authenticated']);await db.exec('set role '+(backend?'service_role':'authenticated'));}
const check=async(name,run)=>{await root();await run();console.log(`PASS ${++passed}: ${name}`);};
const bill=async(amount=1000,who=tenant)=>{await root();const id=randomUUID();await db.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date) values($1,$2,'Original rent title','rent',$3,current_date)",[id,who,amount]);return id;};
const receipt=id=>scalar('select get_payment_receipt($1)',[id]);
const cash=async(id,amount=100)=>{await actor(owner);return scalar("select record_staff_payment($1,$2,$3,'f2f',current_date,'ignored',$4,'Original staff note')",[randomUUID(),id,amount,`cloudinary://authenticated/${owner}/payment/${id}/proof.png`]);};
const txFor=id=>scalar('select id from payment_transactions where charge_id=$1 order by created_at desc,id desc limit 1',[id]);
try {
 await bootstrapFinancialIntegrity(db);
 const legacy=await bill();const original=(await cash(legacy,100)).payment;const legacyTx=await txFor(legacy);const legacyReceipt=await receipt(legacyTx);
 const missing=await bill();await root();await db.exec('alter table payment_receipts add constraint fixture_missing_receipt check(false) not valid');await cash(missing,100);const missingTx=await txFor(missing);await root();await db.exec('alter table payment_receipts drop constraint fixture_missing_receipt');
 const credits=await bill();await root();
 await db.query("insert into billing_charge_actions(charge_id,amount_delta,action_type) values($1,-75,'credit')",[credits]);
 await db.query('insert into rent_charge_adjustments(charge_id,amount_delta) values($1,-25)',[credits]);
 const priorCredits=await one('select amount,remaining_balance,verified_amount from billing_charge_summaries where id=$1',[credits]);
 await applyFinancialIntegrity(db);
 await check('existing adjustments and issued charge credits retain their amounts and balances',async()=>{
   assert.deepEqual(await one('select amount,remaining_balance,verified_amount from billing_charge_summaries where id=$1',[credits]),priorCredits);
   assert.equal(Number((await one('select amount_delta from billing_charge_actions where charge_id=$1',[credits])).amount_delta),-75);
   assert.equal(Number((await one('select amount_delta from rent_charge_adjustments where charge_id=$1',[credits])).amount_delta),-25);
 });
 await check('upgrade preserves old amounts, receipts and transaction identifiers without backfilling historical context',async()=>{
  await actor(owner);const saved=await receipt(legacyTx);
  for(const [key,value] of Object.entries(legacyReceipt))assert.deepEqual(saved[key],value);
  assert.equal(saved.snapshot_source,'legacy');assert.equal((await one('select receipt_context from payment_transactions where id=$1',[legacyTx])).receipt_context,null);
  assert.equal(Number((await one('select remaining_balance from billing_charge_summaries where id=$1',[legacy])).remaining_balance),Number(original.remaining_balance));
  const recovered=await receipt(missingTx);assert.equal(recovered.snapshot_source,'recovery');assert.equal(recovered.id,missingTx);
 });
 await check('manual full and partial payments produce exact immutable receipt snapshots and preserve later receipts',async()=>{
  const id=await bill();await cash(id,250);const first=await txFor(id);const a=await receipt(first);
  assert.equal(a.amount,250);assert.equal(a.balance_after,750);assert.equal(a.environment,'manual');assert.equal(a.snapshot_source,'verification');
  await cash(id,750);const b=await receipt(await txFor(id));assert.equal(b.amount,750);assert.equal(b.balance_after,0);
  assert.deepEqual(await receipt(first),a);assert.equal((await one('select count(*)::int n from payment_receipts where charge_id=$1',[id])).n,2);
 });
 await check('failed receipt creation never reverses payment; delayed recovery retains original name title and partial balance',async()=>{
  const id=await bill();await root();await db.exec('alter table payment_receipts add constraint fixture_receipt_failure check(false) not valid');
  await cash(id,200);const transaction=await txFor(id);assert.equal((await one('select status from payment_transactions where id=$1',[transaction])).status,'verified');
  const originalContext=(await one('select receipt_context from payment_transactions where id=$1',[transaction])).receipt_context;
  await root();await db.exec('alter table payment_receipts drop constraint fixture_receipt_failure');
  await cash(id,300);await root();await db.query("update profiles set full_name='Changed later name' where id=$1",[tenant]);await db.query("update billing_charges set title='Changed later title' where id=$1",[id]);
  await db.query("update payment_transactions set received_on=current_date-3,reviewed_at=now()+interval '1 day' where id=$1",[transaction]);
  await actor(owner);const r=await receipt(transaction);assert.equal(r.tenant_name,'Sample tenant');assert.equal(r.bill_title,'Original rent title');assert.equal(r.balance_after,800);
  assert.equal(Date.parse(r.verified_at),Date.parse(originalContext.verified_at));assert.equal(Date.parse(r.received_at),Date.parse(originalContext.received_at));
  assert.deepEqual(await receipt(transaction),r);
  await root();await db.query("update profiles set full_name='Sample tenant' where id=$1",[tenant]);
 });
 await check('manual proof review binds the selected transaction and never creates a receipt for pending or rejected proof',async()=>{
  const id=await bill();await actor(tenant);
  const pending=await scalar("select submit_payment_transaction($1,'GCash','PENDING-REF','fixture-proof',400)",[id]);const tx=pending.latest_transaction_id;
  await assert.rejects(receipt(tx),/verified payment/);
  await actor(caretaker);await assert.rejects(db.query("select review_payment_transaction($1,true,'Wrong proof',$2)",[id,randomUUID()]),/changed/);
  await db.query("select review_payment_transaction($1,false,'Rejected proof',$2)",[id,tx]);await assert.rejects(receipt(tx),/verified payment/);
  await actor(tenant);const next=await scalar("select submit_payment_transaction($1,'GCash','VERIFIED-REF','fixture-proof',300)",[id]);
  await actor(caretaker);await db.query("select review_payment_transaction($1,true,'Approved proof',$2)",[id,next.latest_transaction_id]);
  const r=await receipt(next.latest_transaction_id);assert.equal(r.amount,300);assert.equal(r.balance_after,700);assert.equal(r.reference_number,'VERIFIED-REF');
  assert.equal(r.snapshot_source,'verification');
 });
 await check('receipt and context history reject modification, including backend direct writes',async()=>{
  await actor(owner);await assert.rejects(db.query('update payment_receipts set amount=1 where id=$1',[legacyTx]));
  await assert.rejects(db.query("update payment_transactions set receipt_context='{}' where id=$1",[legacyTx]));
  await actor(owner,true);await assert.rejects(db.query('delete from payment_receipts where id=$1',[legacyTx]),/immutable/);
  await assert.rejects(db.query("update payment_transactions set receipt_context='{}' where id=$1",[legacyTx]),/immutable/);
 });
 let gatewayBill,session;
 await check('automatic test verification creates a TEST receipt and separates test cash without changing sandbox allocations',async()=>{
  gatewayBill=await bill();await root();await db.exec("update paymongo_test_configuration set deployment_environment='local';update payment_collection_settings set mode='paymongo',paymongo_ready=true,demo_test_credits=true");await db.query('update payment_collection_settings set updated_by=$1',[owner]);
  await db.query('insert into paymongo_test_bills(charge_id) values($1)',[gatewayBill]);await actor(tenant);
  session=(await scalar('select begin_paymongo_advance_payment($1)',[[gatewayBill]])).session;
  await root();await db.query("update paymongo_payment_sessions set status='pending',provider_intent_id='pi_Test',provider_method_id='pm_Test' where id=$1",[session.id]);
  await actor(owner,true);const result=await scalar("select settle_paymongo_payment($1,'pi_Test','pay_Test',100000,'PHP','test',now())",[session.id]);
  const r=await receipt(result.credited_transaction_id);assert.equal(r.environment,'test');assert.equal(r.balance_after,0);
  await root();const summary=await one('select verified_amount,test_verified_amount,remaining_balance,latest_gateway_session_id from billing_charge_summaries where id=$1',[gatewayBill]);
  assert.equal(Number(summary.verified_amount),1000);assert.equal(Number(summary.test_verified_amount),1000);assert.equal(Number(summary.remaining_balance),0);assert.equal(summary.latest_gateway_session_id,session.id);
  await actor(owner,true);await scalar("select settle_paymongo_payment($1,'pi_Test','pay_Test',100000,'PHP','test',now())",[session.id]);
  assert.equal((await one('select count(*)::int n from payment_receipts where charge_id=$1',[gatewayBill])).n,1);
 });
 await check('pending and failed gateway requests produce no confirmed transactions or receipts',async()=>{
   const id=await bill();await root();await db.query('insert into paymongo_test_bills(charge_id) values($1)',[id]);await actor(tenant);
   const pending=(await scalar('select begin_paymongo_advance_payment($1)',[[id]])).session;
   assert.equal((await one('select count(*)::int n from payment_transactions where gateway_session_id=$1',[pending.id])).n,0);
   await root();await db.query("update paymongo_payment_sessions set status='failed' where id=$1",[pending.id]);
   assert.equal((await one('select count(*)::int n from payment_receipts where charge_id=$1',[id])).n,0);
   assert.equal(Number((await one('select remaining_balance from billing_charge_summaries where id=$1',[id])).remaining_balance),1000);
 });
 await check('test-credit classification respects staff tenant and linked guardian billing scope',async()=>{
  const guardian=randomUUID();await root();await db.query("insert into profiles values($1,'Guardian','guardian')",[guardian]);await db.query('insert into guardian_tenant_links values($1,$2)',[guardian,tenant]);
  for(const who of [owner,caretaker,tenant,guardian]){await actor(who);assert.equal(Number(await scalar('select billing_test_verified_amount($1)',[gatewayBill])),1000);}
  await actor(guardian);await assert.rejects(receipt(await txFor(gatewayBill)),/not available/);
  await actor(otherTenant);assert.equal(Number(await scalar('select billing_test_verified_amount($1)',[gatewayBill])),0);await assert.rejects(receipt(legacyTx),/not available/);
 });
 const chargeKey=randomUUID();let created;
 const charge=(key=chargeKey,title='Manual additional charge',specific='Aircon repair')=>scalar("select create_additional_charge($1,$2,'other',125,current_date,'Original notes','Owner approved reason',$3,$4)",[tenant,title,specific,key]);
 await check('Owner additional charge retries retain category specification reason notes and one charge',async()=>{
  await actor(owner);created=await charge();assert.equal(created.charge_created,true);assert.equal(created.specific_category,'Aircon repair');
  const again=await charge();assert.equal(again.id,created.id);assert.equal(again.charge_created,false);
  assert.equal((await one('select count(*)::int n from billing_charges where additional_request_id=$1',[chargeKey])).n,1);
  await assert.rejects(charge(chargeKey,'Changed charge title'),/different details/);
  assert.equal(created.notes,'Original notes');assert.equal(created.terms_snapshot.manual_approval_reason,'Owner approved reason');
  await assert.rejects(charge(randomUUID(),'Valid title',''),/Specify Category/);
 });
 await check('additional charges retain Owner-only API and direct financial mutation restrictions',async()=>{
  for(const who of [caretaker,tenant,otherTenant,randomUUID(),null]){await actor(who);await assert.rejects(charge(randomUUID()),/Owner access/);await assert.rejects(db.query("insert into billing_charges(tenant_id,title,category,original_amount,due_date) values($1,'Bypass','other',1,current_date)",[tenant]));}
 });
 await check('retention is configuration-only, audited for staff and cannot enable deletion',async()=>{
  for(const who of [owner,caretaker]){await actor(who);await db.query("select update_retention_policy_setting('conduct_case_evidence',365,'reviewed','Review configuration only')");}
  assert.equal((await one("select enforcement_enabled from retention_policy_settings where record_key='conduct_case_evidence'")).enforcement_enabled,false);
  assert.equal((await one("select count(*)::int n from retention_policy_events where record_key='conduct_case_evidence'")).n,2);
  await root();await assert.rejects(db.exec("update retention_policy_settings set enforcement_enabled=true where record_key='conduct_case_evidence'"),/check constraint/);
  await actor(tenant);await assert.rejects(db.query("select update_retention_policy_setting('conduct_case_evidence',30,'reviewed','Unauthorized')"),/owners and caretakers/);
 });
 console.log(`${passed} financial receipt, charge retry and retention checks passed.`);
} catch(error){console.error(error.message);process.exitCode=1;}finally{await db.close();}
