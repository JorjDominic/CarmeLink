// Requires an EMPTY, disposable loopback PostgreSQL database; never linked Supabase.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import pg from '../build/phase2_sql_tests/node_modules/pg/lib/index.js';
import {bootstrapPaymongoFixture,id,owner,tenant,source} from './paymongo_phase1_fixture.mjs';
const index=process.argv.indexOf('--local-config');
if(index<0||!process.argv.includes('--disposable')){
 console.log('PENDING EXTERNAL TESTING: provide --disposable --local-config <private JSON file> for an empty local PostgreSQL database.');process.exit(2);
}
const connectionString=JSON.parse(readFileSync(process.argv[index+1],'utf8')).connectionString;
const url=new URL(connectionString);
assert.ok(['127.0.0.1','localhost','[::1]'].includes(url.hostname),'Only loopback databases are allowed');
assert.ok(/^phase1_paymongo_validation_[a-z0-9_]+$/.test(url.pathname.slice(1)),'Dedicated Phase 1 database name required');
const clients=Array.from({length:3},()=>new pg.Client({connectionString,connectionTimeoutMillis:2000}));
const [root,a,b]=clients;
const login=async(client,backend=false)=>{await client.query("select set_config('test.actor',$1,false),set_config('test.jwtrole',$2,false)",[backend?owner:tenant,backend?'service_role':'authenticated']);await client.query('set role '+(backend?'service_role':'authenticated'))};
async function overlap(right,finishLeft){
 const pid=(await b.query('select pg_backend_pid() pid')).rows[0].pid;
 const work=right();let waiting=false;
 for(let i=0;i<100;i++){
  if((await root.query('select wait_event_type from pg_stat_activity where pid=$1',[pid])).rows[0]?.wait_event_type==='Lock'){waiting=true;break}
  await new Promise(resolve=>setTimeout(resolve,20));
 }
 assert.ok(waiting,'Independent lock overlap was not observed');await finishLeft();return await work;
}
try{
 await Promise.all(clients.map(c=>c.connect()));
 assert.equal(Number((await root.query("select count(*) from information_schema.tables where table_schema='public'")).rows[0].count),0,'Database must be empty');
 await bootstrapPaymongoFixture({exec:sql=>root.query(sql),query:(sql,args)=>root.query(sql,args)});
 if(process.argv.includes('--financial-integrity')) await root.query(source('202610160008_payment_receipt_integrity.sql'));
 await root.query("update paymongo_test_configuration set deployment_environment='local'");
 await root.query("update payment_collection_settings set mode='paymongo',paymongo_ready=true,demo_test_credits=true,updated_by=$1",[owner]);
 await root.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date) values($1,$2,'Sample concurrent bill','rent',1000,current_date)",[id(100),tenant]);
 await root.query('insert into paymongo_test_bills(charge_id) values($1)',[id(100)]);
 await Promise.all([login(a),login(b)]);await a.query('begin');await b.query('begin');
 const first=(await a.query('select begin_paymongo_payment($1) p',[id(100)])).rows[0].p;
 const second=await overlap(async()=>{const p=(await b.query('select begin_paymongo_payment($1) p',[id(100)])).rows[0].p;await b.query('commit');return p},()=>a.query('commit'));
 assert.equal(second.session.id,first.session.id);assert.equal(second.is_new,false);
 console.log('PASS independent-session overlapping checkout reuses one payment attempt');
 const session=first.session.id;
 await root.query("update paymongo_payment_sessions set status='pending',provider_intent_id='pi_Concurrent' where id=$1",[session]);
 await Promise.all([a.query('reset role'),b.query('reset role')]);await Promise.all([login(a,true),login(b,true)]);
 const sql="select settle_paymongo_payment($1,'pi_Concurrent','pay_Concurrent',100000,'PHP','test',now()) p";
 await a.query('begin');await b.query('begin');await a.query(sql,[session]);
 await overlap(async()=>{await b.query(sql,[session]);await b.query('commit')},()=>a.query('commit'));
 assert.equal(Number((await root.query('select count(*) from payment_transactions where gateway_session_id=$1',[session])).rows[0].count),1);
 assert.equal(Number((await root.query('select count(*) from payment_receipts')).rows[0].count),1);
 assert.equal(Number((await root.query('select remaining_balance from billing_charge_summaries where id=$1',[id(100)])).rows[0].remaining_balance),0);
 console.log('PASS independent-session overlapping settlement creates one allocation and one receipt');
}catch(error){console.error('Local concurrency validation failed:',error.code??error.message);process.exitCode=1}
finally{await Promise.all(clients.map(c=>c.end().catch(()=>{})))}
