import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {PGlite} from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import {bootstrapFinancialIntegrity,applyFinancialIntegrity} from './financial_integrity_fixture.mjs';
import {source,owner,tenant,otherTenant,caretaker,id} from './paymongo_phase1_fixture.mjs';
const db=new PGlite();
const scalar=async(sql,args=[])=>Object.values((await db.query(sql,args)).rows[0])[0];
async function actor(who){await db.exec('reset role');await db.query("select set_config('test.actor',$1,false)",[who]);await db.exec('set role authenticated');}
async function payment(){await db.exec('reset role');const bill=randomUUID();
 await db.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date) values($1,$2,'Rent','rent',1000,current_date)",[bill,tenant]);
 await actor(owner);await scalar("select record_staff_payment($1,$2,100,'f2f',current_date,'Cash',$3,'Received')",[randomUUID(),bill,`cloudinary://authenticated/${owner}/payment/${bill}/proof.png`]);
 return {bill,tx:await scalar('select id from payment_transactions where charge_id=$1',[bill])};}
const record=(request,tx,number='OR-001',photo=null)=>scalar('select to_jsonb(record_issued_payment_receipt($1,$2,$3,(now() at time zone \'Asia/Manila\')::date,$4))',[request,tx,number,photo]);
try {
 await bootstrapFinancialIntegrity(db);await applyFinancialIntegrity(db);
 await db.exec(source('202610180004_issued_payment_receipts.sql'));
 const a=await payment();const request=randomUUID();
 const receipt=await record(request,a.tx);
 assert.equal(receipt.status,'issued');assert.equal(receipt.environment,'live');
 assert.deepEqual(await record(request,a.tx),receipt);
 await assert.rejects(record(request,a.tx,'changed'),/different receipt/);
 await assert.rejects(record(randomUUID(),a.tx,'OR-002'),/one_active_issued_receipt/);
 const b=await payment();await assert.rejects(record(randomUUID(),b.tx,' or-001 '),/unique/);
 await assert.rejects(scalar("select record_issued_payment_receipt($1,$2,'FUTURE',current_date+2,null)",[randomUUID(),b.tx]),/Receipt date/);
 await assert.rejects(scalar("select record_issued_payment_receipt($1,$2,'PAST',current_date-2,null)",[randomUUID(),b.tx]),/Receipt date/);
 await assert.rejects(record(randomUUID(),randomUUID(),'MISSING'),/verified payment/);
 await assert.rejects(record(randomUUID(),b.tx,'OTHER',`cloudinary://authenticated/${tenant}/payment/${b.bill}/proof.png`),/Invalid receipt attachment/);
 await actor(tenant);await assert.rejects(record(randomUUID(),b.tx),/Staff access/);
 assert.equal(Number(await scalar('select count(*) from issued_payment_receipts')),1);
 await assert.rejects(db.query("update issued_payment_receipts set receipt_number='changed'"),/permission denied/);
 await actor(otherTenant);assert.equal(Number(await scalar('select count(*) from issued_payment_receipts')),0);
 await assert.rejects(scalar('select get_payment_receipt($1)',[a.tx]),/not available/);
 const guardian=id(99);await db.exec('reset role');
 await db.query("insert into profiles values($1,'Guardian','guardian')",[guardian]);
 await db.query('insert into guardian_tenant_links values($1,$2)',[guardian,tenant]);
 await actor(guardian);assert.equal(Number(await scalar('select count(*) from issued_payment_receipts')),1);
 assert.equal((await scalar('select get_payment_receipt($1)',[a.tx])).id,a.tx);
 await actor(caretaker);await assert.rejects(scalar('select to_jsonb(void_issued_payment_receipt($1,$2))',[request,'']),/void reason/);
 const voided=await scalar('select to_jsonb(void_issued_payment_receipt($1,$2))',[request,'Incorrect printed number']);
 assert.equal(voided.status,'voided');assert.equal(voided.receipt_number,'OR-001');
 const replacement=await record(randomUUID(),a.tx,'OR-002');assert.equal(replacement.replaces_id,request);
 await assert.rejects(record(randomUUID(),b.tx,'OR-001'),/unique/);
 assert.equal(Number(await scalar('select remaining_balance from billing_charge_summaries where id=$1',[a.bill])),900);
 await db.exec('reset role');await assert.rejects(db.query('delete from issued_payment_receipts where id=$1',[request]),/cannot be edited/);
 await assert.rejects(db.query("update issued_payment_receipts set receipt_number='changed' where id=$1",[request]),/cannot be edited/);
 // Real sandbox settlement, rather than a relabeled manual payment.
 const sandbox=await payment();await db.exec('reset role');
 await db.exec("update paymongo_test_configuration set deployment_environment='local';update payment_collection_settings set mode='paymongo',paymongo_ready=true,demo_test_credits=true");
 await db.query('update payment_collection_settings set updated_by=$1',[owner]);
 await db.query('insert into paymongo_test_bills(charge_id) values($1)',[sandbox.bill]);
 await actor(tenant);const session=(await scalar('select begin_paymongo_advance_payment($1)',[[sandbox.bill]])).session;
 await db.exec('reset role');await db.query("update paymongo_payment_sessions set status='pending',provider_intent_id='pi_Test',provider_method_id='pm_Test' where id=$1",[session.id]);
 await db.query("select set_config('test.jwtrole','service_role',false)");await db.exec('set role service_role');
 const settled=await scalar("select settle_paymongo_payment($1,'pi_Test','pay_Test',90000,'PHP','test',now())",[session.id]);
 await actor(owner);await db.query("select set_config('test.jwtrole','authenticated',false)");
 const testReceipt=await record(randomUUID(),settled.credited_transaction_id,'OR-001');
 assert.equal(testReceipt.environment,'test');
 console.log('PASS: issuance, duplicate normalization, idempotency, attachment ownership, roles, guardian access, void/replacement and unchanged ledger');
} finally {await db.close();}

