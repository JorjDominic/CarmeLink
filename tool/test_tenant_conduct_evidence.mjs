import {PGlite} from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {bootstrapConductFixture} from './conduct_case_fixture.mjs';
const db=new PGlite();
const ids=Object.fromEntries(['owner','caretaker','tenant','other','guardian','missing'].map(r=>[r,randomUUID()]));
const one=async(sql,args=[])=>(await db.query(sql,args)).rows[0];
const scalar=async(sql,args=[])=>Object.values(await one(sql,args))[0];
async function actor(role){await db.exec('reset role');await db.query("select set_config('test.actor',$1,false)",[ids[role]??'']);await db.exec('set role authenticated');}
async function createCase(status='awaiting_response',published=true){await db.exec('reset role');const id=randomUUID();
 await db.query("insert into conduct_cases(id,tenant_id,category,title,description,incident_at,status,opened_by,tenant_notified_at) values($1,$2,'rule_violation','Case title','Original description',now(),$3,$4,$5)",[id,ids.tenant,status,ids.owner,published?'2026-10-18':null]);return id;}
async function photo(caseId,request,caption='Photo context'){
 await actor('tenant');const path=`${ids.tenant}/${caseId}/${request}/${randomUUID()}.png`;
 await db.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('tenant-conduct-evidence',$1,auth.uid()::text,'{\"mimetype\":\"image/png\",\"size\":100}')",[path]);
 return {storage_path:path,original_name:'evidence.png',content_type:'image/png',size_bytes:100,caption};
}
const submit=(request,caseId,photos=[],kind='response',statement='My explanation of the incident')=>scalar('select submit_tenant_conduct_material($1,$2,$3,$4,\'\',$5)',[request,caseId,kind,statement,JSON.stringify(photos)]);
let passed=0;async function check(name,fn){await fn();console.log(`PASS ${++passed}: ${name}`);}
try{
 await db.exec('create role service_role bypassrls');
 await bootstrapConductFixture(db,ids);
 await db.exec(readFileSync('supabase/migrations/202610180005_tenant_conduct_evidence.sql','utf8'));
 const caseId=await createCase(),request=randomUUID();const first=await photo(caseId,request);
 let response;
 await check('response and photos save atomically with one notification and retry-safe identity',async()=>{
  response=await submit(request,caseId,[first]);assert.equal(await submit(request,caseId,[first]),response);
  assert.equal(Number(await scalar('select count(*) from tenant_conduct_evidence')),1);
  assert.equal(Number(await scalar('select count(*) from tenant_conduct_submissions')),1);
  await assert.rejects(submit(request,caseId,[first],'response','Changed statement'),/different submission/);
  await db.exec('reset role');
  assert.equal(Number(await scalar('select count(*) from conduct_case_responses where case_id=$1',[caseId])),1);
  assert.equal(Number(await scalar("select count(*) from app_notifications where route_id=$1",[caseId])),2);
 });
 await check('tenant reads own registered photos; other tenants and guardians cannot read or submit',async()=>{
  await actor('tenant');assert.equal(Number(await scalar('select count(*) from tenant_conduct_evidence')),1);
  assert.equal(Number(await scalar("select count(*) from storage.objects where bucket_id='tenant-conduct-evidence'")),1);
  for(const role of ['other','guardian']){
   await actor(role);assert.equal(Number(await scalar('select count(*) from tenant_conduct_evidence')),0);
   assert.equal(Number(await scalar("select count(*) from storage.objects where bucket_id='tenant-conduct-evidence'")),0);
   await assert.rejects(submit(randomUUID(),caseId),/Tenant access|not available/);
  }
  await actor('caretaker');assert.equal(Number(await scalar('select count(*) from tenant_conduct_evidence')),1);
  assert.equal(Number(await scalar("select count(*) from storage.objects where bucket_id='tenant-conduct-evidence'")),1);
 });
 await check('tenant uploads cannot expose staff evidence or target another tenant, unpublished cases or existing submissions',async()=>{
  await actor('tenant');assert.equal(Number(await scalar('select count(*) from conduct_case_evidence')),0);
  await assert.rejects(db.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('conduct_case_evidence','staff.png',auth.uid()::text,'{}')"),/row-level security/);
  await assert.rejects(photo(caseId,request),/row-level security/);
  const hidden=await createCase('awaiting_response',false);
  await assert.rejects(photo(hidden,randomUUID()),/row-level security/);
  await actor('other');await assert.rejects(db.query("insert into storage.objects(bucket_id,name,owner_id,metadata) values('tenant-conduct-evidence',$1,auth.uid()::text,'{}')",[`${ids.other}/${caseId}/${randomUUID()}/${randomUUID()}.png`]),/row-level security/);
 });
 await check('invalid, missing, oversized, duplicate and cross-request attachments roll back the statement',async()=>{
  const id=randomUUID();const p=await photo(caseId,id);
  await assert.rejects(submit(id,caseId,[{...p,size_bytes:101}]),/metadata/);
  await assert.rejects(submit(id,caseId,[{...p,storage_path:p.storage_path.replace(/[^/]+$/,'missing.png')}]),/path|Upload/);
  await assert.rejects(submit(id,caseId,[p,p]),/unique/);
  await assert.rejects(submit(id,caseId,Array(6).fill(p)),/at most five/);
  await assert.rejects(submit(randomUUID(),caseId,[p]),/path/);
  await db.exec('reset role');await db.query("update storage.objects set metadata=jsonb_build_object('mimetype','image/png','size',5242881) where name=$1",[p.storage_path]);
  await actor('tenant');await assert.rejects(submit(id,caseId,[{...p,size_bytes:5242881}]),/metadata/);
  await db.exec('reset role');assert.equal(Number(await scalar('select count(*) from conduct_case_responses where case_id=$1',[caseId])),1);
 });
 await check('registered history cannot be edited or deleted; detached uploads can be cleaned up',async()=>{
  await actor('tenant');await db.query('delete from storage.objects where name=$1',[first.storage_path]);
  assert.equal(Number(await scalar('select count(*) from tenant_conduct_evidence')),1);
  await assert.rejects(db.query("update tenant_conduct_evidence set caption='Changed'"),/permission denied/);
  await db.exec('reset role');await assert.rejects(db.query('delete from storage.objects where name=$1',[first.storage_path]),/cannot be replaced/);
  await assert.rejects(db.exec('delete from tenant_conduct_evidence'),/cannot be edited/);
  const id=randomUUID(),p=await photo(caseId,id);await db.query('delete from storage.objects where name=$1',[p.storage_path]);
  await db.exec('reset role');assert.equal(Number(await scalar('select count(*) from storage.objects where name=$1',[p.storage_path])),0);
 });
 await check('appeal attachments retain parent association and do not change the recorded outcome',async()=>{
  const appealCase=await createCase('resolved'),id=randomUUID(),p=await photo(appealCase,id);
  const appeal=await submit(id,appealCase,[p],'appeal','I contest the decision with supporting evidence');
  assert.equal(await submit(id,appealCase,[p],'appeal','I contest the decision with supporting evidence'),appeal);
  assert.equal((await one('select appeal_id,response_id from tenant_conduct_submissions where id=$1',[id])).appeal_id,appeal);
  await db.exec('reset role');assert.equal(await scalar('select status from conduct_cases where id=$1',[appealCase]),'resolved');
  assert.equal(Number(await scalar("select count(*) from app_notifications where data->>'submission_id'=$1",[id])),2);
  await actor('tenant');await assert.rejects(submit(randomUUID(),appealCase,[]),/Responses are closed/);
 });
 console.log(`${passed} tenant evidence workflow checks passed.`);
}catch(e){console.error(e.message,e.where??'',e.query??'');process.exitCode=1;}finally{await db.close();}
