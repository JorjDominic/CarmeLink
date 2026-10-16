// No remote connection: executes real payment SQL in disposable in-memory PostgreSQL.
import {PGlite} from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import assert from 'node:assert/strict';
import {bootstrapPaymongoFixture,id,owner,tenant,otherTenant,caretaker,source} from './paymongo_phase1_fixture.mjs';
const db=new PGlite();let passed=0,next=100;
const check=async(name,run)=>{await root();await run();passed++;console.log(`PASS ${name}`)};
const login=async(who=tenant,backend=false)=>{await db.exec('reset role');await db.query("select set_config('test.actor',$1,false),set_config('test.jwtrole',$2,false)",[who,backend?'service_role':'authenticated']);await db.exec('set role '+(backend?'service_role':'authenticated'))};
const root=()=>db.exec('reset role');
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function bill(amount=1000,who=tenant,category='rent',sample=true){
  await root();const key=id(next++);
  await db.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date) values($1,$2,'Sample bill',$3,$4,current_date)",[key,who,category,amount]);
  if(sample)await db.query('insert into paymongo_test_bills values($1,now())',[key]);return key;
}
const begin=async(ids)=>{await login();return scalar('select begin_paymongo_advance_payment($1) result',[ids])};
async function pending(ids){const p=(await begin(ids)).session;await root();await db.query("update paymongo_payment_sessions set status='pending',provider_intent_id=$2,provider_method_id=$3 where id=$1",[p.id,'pi_'+p.id.replaceAll('-',''),'pm_'+p.id.replaceAll('-','')]);return (await db.query('select * from paymongo_payment_sessions where id=$1',[p.id])).rows[0]}
const settle=async(p,overrides={})=>{await login(owner,true);return scalar('select settle_paymongo_payment($1,$2,$3,$4,$5,$6,$7)',[p.id,overrides.intent??p.provider_intent_id,overrides.payment??'pay_'+p.id.replaceAll('-',''),overrides.amount??p.amount_centavos,overrides.currency??'PHP',overrides.environment??p.environment,'2026-10-16T01:00:00Z'])};
const balance=async(key)=>{await root();return Number(await scalar('select remaining_balance from billing_charge_summaries where id=$1',[key]))};
try {
 await bootstrapPaymongoFixture(db);
 if(process.argv.includes('--financial-integrity')) await db.exec(source('202610160008_payment_receipt_integrity.sql'));
 await check('production default rejects test payments even with the legacy demo-credit flag',async()=>{
  await root();await db.query("update payment_collection_settings set mode='paymongo',paymongo_ready=true,updated_by=$1",[owner]);
  const key=await bill();await assert.rejects(()=>begin([key]),/disposable local or staging/);assert.equal(await balance(key),1000);
 });
 await root();await db.exec("update paymongo_test_configuration set deployment_environment='local'");
 await check('single-bill delegate cannot bypass the guarded test entry point',async()=>{
  await root();await db.exec("update paymongo_test_configuration set deployment_environment='production'");const key=await bill();await login();await assert.rejects(()=>scalar('select begin_paymongo_payment($1)',[key]),/disposable local or staging/);
  await root();await db.exec("update paymongo_test_configuration set deployment_environment='local'");
 });
 await check('sandbox cannot create an attempt against an unregistered bill',async()=>{const key=await bill(1000,tenant,'rent',false);await assert.rejects(()=>begin([key]),/registered sample bills/)});
 await check('client cannot mark the database as staging or register production bills',async()=>{await login(owner);await assert.rejects(()=>db.exec("update paymongo_test_configuration set deployment_environment='local'"),/permission denied/);await assert.rejects(()=>db.query('insert into paymongo_test_bills(charge_id) values($1)',[id(100)]),/permission denied/)});
 await check('test credits must be explicitly enabled and live is blocked in staging',async()=>{
  await root();await db.exec('update payment_collection_settings set demo_test_credits=false');const key=await bill();await assert.rejects(()=>begin([key]),/explicitly enabled/);
  await root();await db.exec("update payment_collection_settings set demo_test_credits=true,environment='live'");await assert.rejects(()=>begin([key]),/Live payments are disabled/);await root();await db.exec("update payment_collection_settings set environment='test'");
 });
 await check('foreign-tenant bills and duplicate bill selections are rejected',async()=>{const a=await bill(),b=await bill(1000,otherTenant);await assert.rejects(()=>begin([b]),/Bill not found/);await assert.rejects(()=>begin([a,a]),/only once/)});
 await check('exact outstanding amount is reused and overlapping requests are rejected',async()=>{const a=await bill(),b=await bill();const first=await begin([a]);const again=await begin([a]);assert.equal(first.session.id,again.session.id);assert.equal(Number(first.session.amount_centavos),100000);await assert.rejects(()=>begin([a,b]),/active payment/)});
 await check('untrusted clients cannot call core creation or backend settlement',async()=>{await login();assert.equal(await scalar("select has_function_privilege('authenticated','public.begin_paymongo_advance_payment_core(uuid[])','EXECUTE')"),false);assert.equal(await scalar("select has_function_privilege('authenticated','public.settle_paymongo_payment(uuid,text,text,bigint,text,text,timestamptz)','EXECUTE')"),false)});
 await check('tampered amount, currency, environment and provider identity never credit a bill',async()=>{const key=await bill(),p=await pending([key]);for(const wrong of [{amount:1},{currency:'USD'},{environment:'live'},{intent:'pi_Wrong'}])await assert.rejects(()=>settle(p,wrong),/does not match/);assert.equal(await balance(key),1000)});
 let confirmed,confirmedBills;
 await check('one verified multi-bill payment atomically allocates exact individual obligations',async()=>{
  const a=await bill(2500),b=await bill(3100);confirmedBills=[a,b];const p=await pending([a,b]);confirmed=await settle(p);
  assert.equal(confirmed.status,'succeeded');assert.equal(await balance(a),0);assert.equal(await balance(b),0);
  assert.equal(Number(await scalar('select sum(amount) from payment_transactions where gateway_session_id=$1',[p.id])),5600);
  assert.equal(Number(await scalar('select count(*) from payment_receipts where id in(select id from payment_transactions where gateway_session_id=$1)',[p.id])),2);
 });
 await check('session environment and enabling owner remain immutable',async()=>{
  await root();await assert.rejects(()=>db.query("update paymongo_payment_sessions set environment='live' where id=$1",[confirmed.id]),/immutable/);
  await assert.rejects(()=>db.query('update paymongo_payment_sessions set enabled_by=$2 where id=$1',[confirmed.id,caretaker]),/immutable/);
 });
 await check('gateway references cannot be reused as manual receipts on another bill',async()=>{
  const key=await bill();await login(owner);
  await assert.rejects(()=>db.query("insert into payment_transactions(charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at,reference_number) values($1,$2,100,'verified',$3,$3,now(),$4)",[key,tenant,owner,confirmed.provider_payment_id]),/cannot be recorded as manual/);
 });
 await check('replayed settlement has no duplicate allocations, receipts or notifications',async()=>{
  const before=await scalar('select count(*) from fixture_notifications');await settle(confirmed);await root();
  assert.equal(Number(await scalar('select count(*) from payment_transactions where gateway_session_id=$1',[confirmed.id])),2);
  assert.equal(await scalar('select count(*) from fixture_notifications'),before);
  await assert.rejects(()=>settle(confirmed,{payment:'pay_Different'}),/conflict/);
 });
 await check('receipts are stable test snapshots, readable by tenant/owner/caretaker only',async()=>{
  for(const who of [tenant,owner,caretaker]){await login(who);const rows=await scalar('select get_paymongo_receipts($1)',[confirmed.id]);assert.equal(rows.length,2);assert.ok(rows.every(r=>r.environment==='test'&&r.reference_number.startsWith('pay_')&&r.verified_at&&r.balance_after===0));}
  await login(otherTenant);await assert.rejects(()=>scalar('select get_paymongo_receipts($1)',[confirmed.id]),/not available/);assert.equal(Number(await scalar('select count(*) from payment_receipts')),0);
 });
 await check('a changed selected balance puts all allocations into reconciliation',async()=>{
  const a=await bill(),b=await bill();const p=await pending([a,b]);await root();await db.query("insert into billing_charge_actions(charge_id,amount_delta,action_type) values($1,-100,'credit')",[b]);
  const result=await settle(p);assert.equal(result.status,'needs_review');assert.equal(await balance(a),1000);assert.equal(Number(await scalar('select count(*) from payment_transactions where gateway_session_id=$1',[p.id])),0);
 });
 await check('existing partial payment stays intact and gateway pays only its remainder',async()=>{
  const key=await bill();await root();await db.query("insert into payment_transactions(charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at,payment_method,reference_number) values($1,$2,250,'verified',$2,$3,now(),'Cash','MANUAL-PARTIAL')",[key,tenant,owner]);
  const p=await pending([key]);assert.equal(Number(p.amount_centavos),75000);await settle(p);assert.equal(await balance(key),0);
  assert.equal(Number(await scalar('select count(*) from payment_transactions where charge_id=$1',[key])),2);
 });
 await check('active gateway request blocks a duplicate manual allocation',async()=>{
  const key=await bill();await pending([key]);await login(owner);
  await assert.rejects(()=>db.query("insert into payment_transactions(charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at) values($1,$2,100,'verified',$3,$3,now())",[key,tenant,owner]),/still active/);
 });
 await check('late confirmation of a cancelled attempt is verified against the actual ledger',async()=>{const key=await bill(),p=await pending([key]);await root();await db.query("update paymongo_payment_sessions set status='cancelled' where id=$1",[p.id]);assert.equal((await settle(p)).status,'succeeded');assert.equal(await balance(key),0)});
 await check('notification failure preserves payment and retries without duplicate receipts',async()=>{
  const key=await bill(),p=await pending([key]);await root();await db.exec('update fixture_failures set notifications=true');let saved=await settle(p);assert.equal(saved.status,'succeeded');assert.equal(await balance(key),0);
  assert.equal(await scalar('select notification_pending from paymongo_payment_sessions where id=$1',[p.id]),true);
  await db.query("update paymongo_payment_sessions set last_checked_at=now()-interval '10 minutes' where id=$1",[p.id]);
  await login(owner,true);const retries=(await db.query('select * from claim_paymongo_reconciliation()')).rows;assert.ok(retries.some(r=>r.id===p.id&&r.status==='succeeded'));
  await root();
  await db.exec('update fixture_failures set notifications=false');await settle(p);await root();
  assert.equal(await scalar('select notification_pending from paymongo_payment_sessions where id=$1',[p.id]),false);
  assert.equal(Number(await scalar('select count(*) from fixture_notifications where event_key like $1',['paymongo-paid:'+p.id+':%'])),2);
 });
 await check('receipt-generation failure preserves payment and safe regeneration uses its transaction ID',async()=>{
  const key=await bill(),p=await pending([key]);await root();await db.exec("alter table payment_receipts add constraint fixture_receipt_failure check(false) not valid");
  const saved=await settle(p);assert.equal(saved.status,'succeeded');assert.equal(await balance(key),0);assert.equal(Number(await scalar('select count(*) from payment_receipts where id=$1',[saved.credited_transaction_id])),0);
  await db.exec('alter table payment_receipts drop constraint fixture_receipt_failure');await login();
  const first=await scalar('select get_payment_receipt($1)',[saved.credited_transaction_id]);const second=await scalar('select get_payment_receipt($1)',[saved.credited_transaction_id]);assert.deepEqual(first,second);assert.equal(first.id,saved.credited_transaction_id);
 });
 await check('manual verification still creates a manual receipt and reduces only its own bill',async()=>{
  const key=await bill();await root();await db.exec("update payment_collection_settings set mode='manual'");await login(owner);
  const transaction=await scalar("insert into payment_transactions(charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at,payment_method,reference_number) values($1,$2,100,'verified',$3,$3,now(),'Cash','MANUAL-ONLY') returning id",[key,tenant,owner]);
  const receipt=await scalar('select get_payment_receipt($1)',[transaction]);assert.equal(receipt.environment,'manual');assert.equal(await balance(key),900);
 });
 await check('receipt metadata cannot be rewritten by an authenticated client',async()=>{await login(owner);await assert.rejects(()=>db.exec("update payment_receipts set amount=1"),/permission denied/)});
 console.log(`${passed} isolated PostgreSQL checks passed. Independent-session races and real PayMongo webhooks are NOT tested by this script.`);
} finally {await db.close()}
