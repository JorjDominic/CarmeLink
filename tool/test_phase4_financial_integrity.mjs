// Isolated fixtures only. Optional real engine mode requires an EMPTY disposable local DB.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
import {bootstrapOccupancyFixture} from './contract_occupancy_test_fixture.mjs';
const source=f=>readFileSync(`supabase/migrations/${f}`,'utf8').replaceAll('\r\n','\n');
const actual=process.argv.includes('--real-postgres');let db,clients=[];
if(actual) {
  assert.ok(process.argv.includes('--disposable'),'Explicit disposable flag required');
  const index=process.argv.indexOf('--local-config');assert.ok(index>=0);
  const url=new URL(JSON.parse(readFileSync(process.argv[index+1],'utf8')).connectionString);
  if(process.argv.includes('--docker-network')) {url.hostname='carmelink_phase2_validation_pg2';url.port='5432';}
  assert.ok(['localhost','127.0.0.1','[::1]',...(process.argv.includes('--docker-network')?['carmelink_phase2_validation_pg2']:[])].includes(url.hostname));
  assert.ok(/^phase2_validation_[a-z0-9_]+$/.test(url.pathname.slice(1)));
  const {default:pg}=await import('../build/phase2_sql_tests/node_modules/pg/lib/index.js');
  clients=[new pg.Client({connectionString:url.toString()}),new pg.Client({connectionString:url.toString()}),new pg.Client({connectionString:url.toString()})];
  await Promise.all(clients.map(c=>c.connect()));
  assert.equal((await clients[0].query("select count(*)::int n from pg_tables where schemaname not in ('pg_catalog','information_schema')")).rows[0].n,0,'Database must be empty');
  db={query:(sql,p)=>clients[0].query(sql,p),exec:sql=>clients[0].query(sql)};
} else {
  const {PGlite}=await import('../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js');db=new PGlite();
}
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let sequence=20,passed=0;const owner=id(1),caretaker=id(2);
const row=async(sql,p=[]) => (await db.query(sql,p)).rows[0];
const actor=who=>db.query("select set_config('test.actor',$1,false)",[who]);
const check=async(name,run)=>{await run();passed++;console.log(`PASS ${name}`);};
async function fixture(capacity=4) {
  await db.exec('begin');
  const room=id(sequence++);await db.query("insert into rooms(id,room_number,floor,capacity) values($1,$2,'Ground',$3)",[room,`QA-${sequence}`,capacity]);
  const tenants=[],beds=[];
  for(let i=0;i<capacity;i++) {
    const tenant=id(sequence++),bed=id(sequence++);tenants.push(tenant);beds.push(bed);
    await db.query("insert into profiles values($1::uuid,'tenant','QA Tenant '||$1::text,now())",[tenant]);
    await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,$3)",[bed,room,`Bed ${i+1}`]);
    await db.query('insert into tenant_details(profile_id) values($1)',[tenant]);
  }
  await db.exec('commit');
  return {room,tenants,beds};
}
const prepare=async(f,n)=>(await row("select prepare_contract_occupancy($1,$2,6000,$3::jsonb,current_date,current_date+60,'QA rent') ids",[f.room,n===1?'solo':'shared',JSON.stringify(f.tenants.slice(0,n).map((tenant,i)=>({tenant_id:tenant,bed_id:f.beds[i],security_deposit:'1500.00'})))])).ids;
async function approve(c) {
  await db.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[c]);
  await db.query("insert into contract_requirements values($1,true,'verified')",[c]);
  await db.query("insert into contract_documents values($1::uuid,'generated',1,'not_required',$1::text||'/original'),($1::uuid,'signed',1,'verified',$1::text||'/signed')",[c]);
  await db.query("insert into storage.objects values('contract-documents',$1::text||'/signed')",[c]);
  await db.query("update tenant_contracts set signature_status='verified' where id=$1",[c]);
}
const charge=async(tenant,category='other',specific='Aircon repair',amount='100',reason='Owner approved') => row('select create_additional_charge($1,$2,$3,$4,current_date,$5,$6,$7) c',[tenant,'QA manual charge',category,amount,'Original notes',reason,specific]);
const submit=async(bill,tenant,amount,reference)=>{await actor(tenant);return (await row("select submit_payment_transaction($1,'GCash',$2,$3,$4) p",[bill,reference,`${tenant}/${bill}/qa-receipt.png`,amount])).p;};
const review=(bill,approve,expected)=>row('select review_payment_transaction($1,$2,$3,$4) p',[bill,approve,'QA administrative review',expected]);
try {
  const {legacyFixture}=await bootstrapOccupancyFixture(db,fixture);
  // Replace only the empty minimal billing fixture with real financial tables,
  // RLS, immutable-ledger triggers and the latest summary. Existing rent guards remain.
  await db.exec('drop table billing_charges');
  const base=source('202609200001_contract_billing_synchronization.sql');
  await db.exec(base.slice(base.indexOf('create table public.billing_charges'),base.indexOf('alter table public.billing_charges enable row level security')));
  await db.exec(base.slice(base.indexOf('alter table public.billing_charges enable row level security'),base.indexOf('-- Preserve every legacy invoice')));
  await db.exec(base.slice(base.indexOf('create or replace function public.validate_payment_transaction'),base.indexOf('create or replace view public.billing_charge_summaries')));
  await db.exec('alter table billing_charges add column notes text;create table rent_charge_adjustments(charge_id uuid,amount_delta numeric)');
  const utility=source('202609230001_separate_rent_utility_billing.sql');
  await db.exec(utility.slice(0,utility.indexOf('create or replace view public.billing_charge_summaries')));
  const overrides=source('202609230002_audited_rent_rate_overrides.sql');
  const overrideStart=overrides.indexOf('create or replace function public.apply_rent_rate_override(');
  await db.exec(overrides.slice(overrideStart,overrides.indexOf('$$;',overrideStart)+3));
  await db.exec(source('202609260001_audited_billing_actions.sql'));
  const safeguards=source('202610080006_jorge_contracts_and_staff_receipts.sql');
  await db.exec(safeguards.slice(safeguards.indexOf('create or replace function public.guard_contract_price_terms()')));
  await db.exec('alter table billing_charge_actions add column deposit_deduction_id uuid');
  const staff=source('202610080001_staff_received_payments.sql');
  await db.exec(staff.slice(staff.indexOf('create or replace function public.submit_payment_transaction'),staff.indexOf('create or replace function public.review_payment_transaction')));
  await db.exec(source('202610090010_system_qa_partial_payment_proof_visibility.sql'));
  await db.exec(source('202610130003_room_contract_occupancy_display.sql'));
  for(const [index,paid] of [[0,0],[1,400],[2,1000]]) {
    const bill=id(800000+index);
    await db.query("insert into billing_charges(id,tenant_id,title,category,original_amount,due_date,created_by) values($1,$2,'Existing historical rent','rent',1000,current_date-1,$3)",[bill,legacyFixture.tenants[0],owner]);
    if(paid) await db.query("insert into payment_transactions(charge_id,tenant_id,amount,status,submitted_by,reviewed_by,reviewed_at) values($1,$2,$3,'verified',$2,$4,now())",[bill,legacyFixture.tenants[0],paid,owner]);
  }
  const before=(await db.query('select id,monthly_rent,security_deposit from tenant_contracts order by id')).rows;
  const oldCharges=(await db.query('select * from billing_charges order by id')).rows;
  const oldTransactions=(await db.query('select * from payment_transactions order by id')).rows;
  const financialSql='select id,amount,due_date,status,verified_amount,remaining_balance,deposit_applied_amount from billing_charge_summaries order by id';
  const oldTotals=(await db.query(financialSql)).rows;
  await db.exec(source('202610130004_payment_verification_charge_categories.sql'));
  await db.exec('grant select on profiles,rent_charge_adjustments,guardian_tenant_links to authenticated');
  await check('migration preserves existing paid partial unpaid charges transactions deposits and summary totals',async()=>{
    assert.deepEqual((await db.query('select id,monthly_rent,security_deposit from tenant_contracts order by id')).rows,before);
    assert.deepEqual((await db.query('select * from billing_charges order by id')).rows,oldCharges);
    assert.deepEqual((await db.query('select * from payment_transactions order by id')).rows,oldTransactions);
    assert.deepEqual((await db.query(financialSql)).rows,oldTotals);
  });
  await db.exec(source('202610160004_dynamic_physical_room_capacity.sql'));
  await db.exec(source('202610160005_standard_shared_contract_occupancy.sql'));
  for(const n of [1,2,3,4]) await check(`${n} tenants receive their approved individual rent with unchanged cycles and no duplicates`,async()=>{
    const f=await fixture(),ids=await prepare(f,n);
    for(const c of ids) {await approve(c);await db.query('select activate_tenant_contract($1)',[c]);}
    const bills=(await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[ids])).rows;
    assert.ok(bills.length>n);assert.ok(bills.every(b=>b.category==='rent'&&Number(b.original_amount)===6000/n));
    assert.ok(bills.every(b=>String(b.due_date)===String(b.period_start)));
    for(const c of ids) await db.query('select generate_contract_billing_charges($1)',[c]);
    assert.deepEqual((await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[ids])).rows,bills);
    await db.query("update tenant_assignments set status='ended',ends_on=current_date where tenant_id=$1",[f.tenants[n-1]]);
    await db.query("update tenant_contracts set status='terminated' where id=$1",[ids[n-1]]);
    assert.deepEqual((await db.query('select * from billing_charges where contract_id=any($1::uuid[]) order by id',[ids])).rows,bills);
  });
  const f=await fixture();const tenant=f.tenants[0];
  await check('Standard Shared fixed signed rents and bills survive another roommate joining',async()=>{
    const f=await fixture();
    const members=f.tenants.slice(0,2).map((tenant,i)=>({tenant_id:tenant,bed_id:f.beds[i],security_deposit:'1500.00',monthly_rent:String(2500+i*200)}));
    const ids=(await row("select prepare_contract_occupancy($1,'standard_shared',6000,$2::jsonb,current_date,current_date+60) ids",[f.room,JSON.stringify(members)])).ids;
    for(const c of ids){await approve(c);await db.query('select activate_tenant_contract($1)',[c]);}
    const sql='select id,contract_id,category,original_amount,due_date,period_start,period_end,terms_snapshot from billing_charges where contract_id=any($1::uuid[]) order by id';
    const before=(await db.query(sql,[ids])).rows;
    const rates=(await db.query('select id,monthly_rent,occupancy_snapshot from tenant_contracts where id=any($1::uuid[]) order by id',[ids])).rows;
    for(let i=0;i<2;i++){const rents=before.filter(b=>b.contract_id===ids[i]&&b.category==='rent');assert.ok(rents.length>0);assert.ok(rents.every(b=>Number(b.original_amount)===2500+i*200));}
    const newcomer=(await row("select prepare_contract_occupancy($1,'standard_shared',6000,$2::jsonb,current_date,current_date+60) ids",[f.room,JSON.stringify([{tenant_id:f.tenants[2],bed_id:f.beds[2],security_deposit:1500,monthly_rent:3100}])])).ids;
    await approve(newcomer[0]);await db.query('select activate_tenant_contract($1)',[newcomer[0]]);
    for(const c of [...ids,...newcomer])await db.query('select generate_contract_billing_charges($1)',[c]);
    assert.deepEqual((await db.query(sql,[ids])).rows,before);
    assert.deepEqual((await db.query('select id,monthly_rent,occupancy_snapshot from tenant_contracts where id=any($1::uuid[]) order by id',[ids])).rows,rates);
    const newBills=(await db.query("select original_amount from billing_charges where contract_id=$1 and category='rent'",[newcomer[0]])).rows;
    assert.ok(newBills.length>0);assert.ok(newBills.every(b=>Number(b.original_amount)===3100));
  });
  await check('Other specification reason notes and amount persist in existing metadata',async()=>{
    const c=(await charge(tenant)).c;assert.equal(c.specific_category,'Aircon repair');assert.equal(c.notes,'Original notes');
    assert.equal(c.terms_snapshot.manual_approval_reason,'Owner approved');assert.equal(c.category,'other');
    for(const specific of [null,'',' ']) await assert.rejects(charge(tenant,'other',specific),/Specify Category/);
    await assert.rejects(charge(tenant,'damage','Hidden old category'),/only applies/);
    await assert.rejects(charge(tenant,'other','Valid','NaN'),/positive amount/);
    await assert.rejects(charge(tenant,'other','Valid','1.001'),/decimal/);
    await assert.rejects(charge(tenant,'other','Valid','100',''),/approval reason/);
    const fixed=(await row("select create_additional_charge($1,'Fixed category','damage',50,current_date,null,'Approved') c",[tenant])).c;
    assert.equal(fixed.category,'damage');assert.equal(fixed.specific_category,null);
    await assert.rejects(db.query("select create_additional_charge($1,'Old Other','other',50,current_date,null,'Approved')",[tenant]),/Specify Category/);
  });
  await check('Owner-only additional charges and staff-only review reject invalid roles and sessions',async()=>{
    for(const who of [caretaker,tenant,'',id(999999)]) {
      await actor(who);await assert.rejects(charge(tenant),/Owner access/);
    }
    for(const who of [tenant,'',id(999999)]) {
      await actor(who);await assert.rejects(review(id(999),true,id(998)),/Staff access/);
    }
    await actor(owner);
  });
  await check('partial and rejected proof states remain separate from bill balance and retain audit/evidence',async()=>{
    const c=(await charge(tenant,'damage',null,'1000')).c;
    const first=await submit(c.id,tenant,400,'QA-PARTIAL-1');await actor(caretaker);
    const confirmed=(await review(c.id,true,first.latest_transaction_id)).p;
    assert.equal(confirmed.status,'partially_paid');assert.equal(confirmed.latest_transaction_status,'verified');
    assert.equal(Number(confirmed.verified_amount),400);assert.equal(Number(confirmed.remaining_balance),600);
    const second=await submit(c.id,tenant,200,'QA-PARTIAL-2');await actor(owner);
    const rejected=(await review(c.id,false,second.latest_transaction_id)).p;
    assert.equal(rejected.status,'partially_paid');assert.equal(rejected.latest_transaction_status,'rejected');
    assert.equal(Number(rejected.verified_amount),400);assert.equal(Number(rejected.remaining_balance),600);
    assert.ok(rejected.receipt_path.endsWith('qa-receipt.png'));assert.equal(rejected.review_notes,'QA administrative review');
    const pending=await submit(c.id,tenant,600,'QA-FINAL');await actor(owner);
    await assert.rejects(review(c.id,true,second.latest_transaction_id),/submission changed/);
    await assert.rejects(review(c.id,null,pending.latest_transaction_id),/approval decision/);
    const paid=(await review(c.id,true,pending.latest_transaction_id)).p;
    assert.equal(paid.status,'verified');assert.equal(Number(paid.verified_amount),1000);
    await assert.rejects(review(c.id,true,pending.latest_transaction_id),/submission changed/);
    assert.equal((await row('select count(*)::int n from payment_transactions where charge_id=$1',[c.id])).n,3);
    assert.equal(Number((await row('select original_amount from billing_charges where id=$1',[c.id])).original_amount),1000);
  });
  await check('pending duplicates overpayments unrelated charges and immutable paid history are protected',async()=>{
    const c=(await charge(tenant,'damage',null,'100')).c;
    const other=(await charge(tenant,'cleaning',null,'75')).c;
    const otherBefore=await row('select * from billing_charges where id=$1',[other.id]);
    const p=await submit(c.id,tenant,100,'QA-DUP');
    await assert.rejects(submit(c.id,tenant,50,'QA-DUP2'),/awaiting verification/);
    await actor(owner);await review(c.id,true,p.latest_transaction_id);
    await assert.rejects(submit(c.id,tenant,1,'QA-OVER'),/already paid/);await actor(owner);
    await assert.rejects(db.query('update billing_charges set original_amount=200 where id=$1',[c.id]),/immutable/);
    assert.deepEqual(await row('select * from billing_charges where id=$1',[other.id]),otherBefore);
  });
  await check('summary RLS retains tenant scope while staff can read verified totals',async()=>{
    await actor(tenant);await db.exec('set role authenticated');
    assert.ok((await db.query('select * from billing_charge_summaries')).rows.every(c=>c.tenant_id===tenant));
    await assert.rejects(charge(tenant),/Owner access/);await db.exec('reset role');await actor(owner);
  });
  if(actual) await check('two independent staff approvals allocate a pending proof exactly once',async()=>{
    const c=(await charge(tenant,'damage',null,'1000')).c;const pending=await submit(c.id,tenant,350,'QA-RACE');
    const [a,b]=clients.slice(1);
    const attempt=async(client,who)=>{
      await client.query('begin');await client.query("select set_config('test.actor',$1,true)",[who]);
      try {await client.query('select review_payment_transaction($1,true,$2,$3)',[c.id,'Concurrent review',pending.latest_transaction_id]);await client.query('commit');return true;}
      catch(error) {await client.query('rollback');assert.match(error.message,/submission changed/);return false;}
    };
    const result=await Promise.all([attempt(a,owner),attempt(b,caretaker)]);assert.equal(result.filter(Boolean).length,1);
    await actor(owner);const totals=await row('select verified_amount,remaining_balance from billing_charge_summaries where id=$1',[c.id]);
    assert.equal(Number(totals.verified_amount),350);assert.equal(Number(totals.remaining_balance),650);
  });
  console.log(`Passed ${passed} Phase 4 financial checks on ${actual?'real PostgreSQL with independent review sessions':'PGlite (serialized)'}; full Supabase/gateway/device verification remains pending.`);
} catch(error) {
  console.error(`Phase 4 validation failed: ${error.message}`);process.exitCode=1;
} finally {if(actual) await Promise.all(clients.map(c=>c.end()));else await db.close();}
