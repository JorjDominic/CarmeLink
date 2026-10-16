// Run after the financial receipt fixture, against that disposable loopback database only.
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import pg from '../build/phase2_sql_tests/node_modules/pg/lib/index.js';
import {owner,tenant} from './paymongo_phase1_fixture.mjs';
const at=process.argv.indexOf('--local-config');assert.ok(at>=0&&process.argv.includes('--disposable'));
const config=JSON.parse(readFileSync(process.argv[at+1],'utf8'));const url=new URL(config.connectionString);
assert.ok(['127.0.0.1','localhost','[::1]'].includes(url.hostname));assert.match(url.pathname,/^\/carmelink_financial_validation_[a-z0-9_]+$/);
const clients=Array.from({length:3},()=>new pg.Client(config));const [root,a,b]=clients;
const one=async(sql,args=[])=>(await root.query(sql,args)).rows[0];
let passed=0;const check=async(name,run)=>{await run();console.log(`PASS ${++passed}: ${name}`);};
async function actor(c){await c.query("select set_config('test.actor',$1,false),set_config('test.jwtrole','authenticated',false)",[owner]);await c.query('set role authenticated');}
async function attempt(c,action){await c.query('begin');await c.query("set local statement_timeout='8s'");try{const result=await action();await c.query('commit');return {ok:true,result};}catch(e){await c.query('rollback');return {ok:false,code:e.code,message:e.message};}}
async function bill(amount=1000){const id=randomUUID();await root.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date) values($1,$2,'Concurrent rent','rent',$3,current_date)",[id,tenant,amount]);return id;}
const received=(c,id,request,amount)=>c.query("select record_staff_payment($1,$2,$3,'f2f',current_date,'ignored',$4,'Concurrent fixture') p",[request,id,amount,`cloudinary://authenticated/${owner}/payment/${id}/proof.png`]);
try {
 await Promise.all(clients.map(c=>c.connect()));await Promise.all([actor(a),actor(b)]);
 await check('concurrent additional-charge retries create one approved charge',async()=>{
  const key=randomUUID();const sql="select create_additional_charge($1,'Concurrent approved repair','other',125,current_date,'Fixture notes','Owner approved reason','Aircon repair',$2) p";
  const results=await Promise.all([a,b].map(c=>attempt(c,()=>c.query(sql,[tenant,key]))));assert.ok(results.every(r=>r.ok));
  assert.equal(results[0].result.rows[0].p.id,results[1].result.rows[0].p.id);
  assert.equal(results.filter(r=>r.result.rows[0].p.charge_created).length,1);
  assert.equal((await one('select count(*)::int n from billing_charges where additional_request_id=$1',[key])).n,1);
 });
 await check('duplicate staff payment requests produce one allocation and canonical receipt',async()=>{
  const id=await bill(),key=randomUUID();const results=await Promise.all([a,b].map(c=>attempt(c,()=>received(c,id,key,200))));assert.ok(results.every(r=>r.ok));
  assert.equal(results.filter(r=>r.result.rows[0].p.is_new).length,1);
  const transaction=await one('select id from payment_transactions where staff_request_id=$1',[key]);
  assert.equal((await one('select count(*)::int n from payment_transactions where charge_id=$1',[id])).n,1);
  assert.equal((await one('select count(*)::int n from payment_receipts where id=$1',[transaction.id])).n,1);
  const wrongBill=await bill();const changed=await attempt(a,()=>received(a,wrongBill,key,200));assert.equal(changed.ok,false);assert.match(changed.message,/different details/);
 });
 await check('competing payments cannot over-allocate a bill or corrupt receipt balances',async()=>{
  const id=await bill(500);const results=await Promise.all([a,b].map(c=>attempt(c,()=>received(c,id,randomUUID(),300))));
  assert.equal(results.filter(r=>r.ok).length,1);assert.ok(results.filter(r=>!r.ok).every(r=>!['40P01','57014'].includes(r.code)));
  const row=await one('select verified_amount,remaining_balance from billing_charge_summaries where id=$1',[id]);assert.equal(Number(row.verified_amount),300);assert.equal(Number(row.remaining_balance),200);
  assert.equal(Number((await one('select balance_after from payment_receipts where charge_id=$1',[id])).balance_after),200);
 });
 await check('concurrent receipt recovery returns the same immutable snapshot without a second payment',async()=>{
  const id=await bill();await root.query('alter table payment_receipts add constraint concurrency_receipt_failure check(false) not valid');
  assert.equal((await attempt(a,()=>received(a,id,randomUUID(),250))).ok,true);
  await root.query('alter table payment_receipts drop constraint concurrency_receipt_failure');const tx=(await one('select id from payment_transactions where charge_id=$1',[id])).id;
  const results=await Promise.all([a,b].map(c=>attempt(c,()=>c.query('select get_payment_receipt($1) r',[tx]))));assert.ok(results.every(r=>r.ok));
  assert.deepEqual(results[0].result.rows[0].r,results[1].result.rows[0].r);assert.equal(results[0].result.rows[0].r.balance_after,750);
  assert.equal((await one('select count(*)::int n from payment_transactions where charge_id=$1',[id])).n,1);
  assert.equal((await one('select count(*)::int n from payment_receipts where charge_id=$1',[id])).n,1);
 });
 console.log(`${passed} independent PostgreSQL financial concurrency checks passed.`);
}catch(e){console.error(e.message);process.exitCode=1;}finally{await Promise.allSettled(clients.map(c=>c.end()));}
