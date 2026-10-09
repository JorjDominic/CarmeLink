// Isolated PostgreSQL checks. No Supabase connection or real tenant records.
import { PGlite } from '../build/phase2_sql_tests/node_modules/@electric-sql/pglite/dist/index.js';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
const source=f=>readFileSync(`supabase/migrations/${f}`,'utf8');
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const owner=id(1), caretaker=id(2), stranger=id(3), guardian=id(4);
const hash='a'.repeat(64), signatureHash='b'.repeat(64);
const actor=(uid,role)=>db.query("select set_config('test.actor',$1,false),set_config('test.role',$2,false)",[uid,role]);
const row=async(sql,p=[]) => (await db.query(sql,p)).rows[0];
let sequence=100,passed=0;
const check=async(name,fn)=>{await fn();passed++;console.log(`PASS ${name}`);};
const propose=async(f,date=null)=>(await row("select propose_room_transfer($1,$2,coalesce($3::date,(now() at time zone 'Asia/Manila')::date),'Room transfer requested') id",[f.tenant,f.destination,date])).id;
const transfer=t=>row('select * from room_transfers where id=$1',[t]);
async function object(path,mime='image/png'){
  await db.query("insert into storage.objects(bucket_id,name,metadata,owner_id) values('room-amendments',$1,jsonb_build_object('mimetype',$2::text,'size',100),auth.uid()::text)",[path,mime]);
}
async function publish(t){const path=`${t}/documents/amendment.pdf`;await object(path,'application/pdf');
  await db.query('select publish_room_transfer($1,$2,$3)',[t,path,hash]);}
async function sign(t,role,name=null){
  const path=`${t}/signatures/${role}-${sequence++}.png`;await object(path);
  await db.query('select sign_room_transfer($1,$2,$3,$4,$5,$6)',[t,role,path,signatureHash,hash,name]);
}
async function verify(t,role='tenant'){
  await db.query("select review_room_transfer_signature(id,true,'Reviewed original signature') from room_transfer_signers where transfer_id=$1 and signer_role=$2",[t,role]);
}
async function fixture({guardianRequired=false,witnessRequired=false}={}){
  const tenant=id(sequence++), contract=id(sequence++), r1=id(sequence++),r2=id(sequence++),
    sourceBed=id(sequence++),destination=id(sequence++),assignment=id(sequence++);
  await db.query("insert into profiles values($1,'Fixture tenant','tenant')",[tenant]);
  await db.query("insert into rooms(id,room_number,floor,capacity) values($1::uuid,$1::text,'1',4),($2::uuid,$2::text,'2',4)",[r1,r2]);
  await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,'Bed A'),($3,$4,'Bed B')",[sourceBed,r1,destination,r2]);
  await db.query('insert into tenant_assignments(id,tenant_id,bed_space_id) values($1,$2,$3)',[assignment,tenant,sourceBed]);
  await db.query("insert into tenant_contracts(id,tenant_id,contract_number,status,signature_status,starts_on,ends_on,monthly_rent,security_deposit) values($1::uuid,$2,$1::text,'active','verified',current_date-30,current_date+365,3000,3000)",[contract,tenant]);
  await db.query('insert into tenant_details(profile_id) values($1)',[tenant]);
  for(const role of ['lessor','tenant',...(guardianRequired?['guardian']:[]),...(witnessRequired?['witness']:[])])
    await db.query('insert into contract_signers values($1,$2,true)',[contract,role]);
  if(guardianRequired) await db.query("insert into guardian_tenant_links(guardian_id,tenant_id,is_primary) values($1,$2,true)",[guardian,tenant]);
  return {tenant,contract,r1,r2,sourceBed,destination,assignment};
}
try{
  await db.exec(`create role anon;create role authenticated;create schema auth;create schema storage;
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create function current_user_role() returns text language sql as $$select nullif(current_setting('test.role',true),'')$$;
    create function is_staff() returns boolean language sql as $$select public.current_user_role() in ('owner','caretaker')$$;
    create table profiles(id uuid primary key,full_name text,role text);
    create table tenant_contracts(id uuid primary key,tenant_id uuid,contract_number text,status text,signature_status text,
      starts_on date,ends_on date,monthly_rent numeric,security_deposit numeric,previous_contract_id uuid);
    create table tenant_details(profile_id uuid primary key);
    create table contract_signers(contract_id uuid,signer_role text,is_required boolean);
    create table move_out_cases(id uuid primary key default gen_random_uuid(),tenant_id uuid,contract_id uuid,status text default 'notice_submitted');
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,metadata jsonb,owner_id text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql as $$select string_to_array($1,'/')$$;
    create function storage.filename(text) returns text language sql as $$select reverse(split_part(reverse($1),'/',1))$$;
    create table notices(title text,recipient uuid);
    create function emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$insert into public.notices values($5,$1)$$;
    create function emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer)
      returns void language sql as $$insert into public.notices values($2,null)$$;
  `);
  const core=source('202609070002_core_dormitory_structure.sql');
  await db.exec(core.slice(0,core.indexOf('create or replace function public.set_updated_at')));
  await db.exec(`alter table rooms add column is_active boolean not null default true;
    create function is_guardian_of(uuid) returns boolean language sql security definer as $$
      select exists(select 1 from public.guardian_tenant_links where tenant_id=$1 and guardian_id=auth.uid())$$;
    grant usage on schema public,auth,storage to authenticated;
    grant select,insert,delete on storage.objects to authenticated;
  `);
  await db.exec(source('202609100002_complete_tenant_directory.sql'));
  await db.exec(source('202610090006_signed_room_transfers.sql'));
  await db.query("insert into profiles values($1,'Owner','owner'),($2,'Caretaker','caretaker'),($3,'Stranger','tenant'),($4,'Guardian','guardian')",[owner,caretaker,stranger,guardian]);
  await actor(owner,'owner');
  const f=await fixture(), t=await propose(f);
  const original=await row('select to_jsonb(c) snapshot from tenant_contracts c where id=$1',[f.contract]);
  await check('proposal reserves the destination and preserves the current assignment',async()=>{
    assert.equal((await row('select status from bed_spaces where id=$1',[f.destination])).status,'reserved');
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.assignment])).status,'active');
    assert.equal((await row('select count(*)::int n from notices')).n,0);
    await assert.rejects(propose(f),/already pending/);
  });
  await check('owner notice is sent only after publishing a stored amendment PDF',async()=>{
    await assert.rejects(db.query('select publish_room_transfer($1,$2,$3)',[t,`${t}/documents/missing.pdf`,hash]),/Upload the amendment/);
    await publish(t);assert.equal((await transfer(t)).status,'awaiting_signatures');
    assert.equal((await row('select count(*)::int n from notices')).n,1);
    await db.query('select publish_room_transfer($1,$2,$3)',[t,`${t}/documents/amendment.pdf`,hash]);
    assert.equal((await row('select count(*)::int n from notices')).n,1);
  });
  await check('legacy reassignment and direct writes cannot bypass amendment signatures',async()=>{
    await assert.rejects(db.query('select assign_tenant_bed($1,$2)',[f.tenant,f.sourceBed]),/pending room amendment|signed room amendment/);
    await assert.rejects(db.query('update tenant_assignments set bed_space_id=$2 where id=$1',[f.assignment,f.destination]),/signed room amendment/);
    await assert.rejects(db.query('select end_tenant_assignment($1)',[f.tenant]),/pending room amendment/);
    await assert.rejects(db.query('update bed_spaces set status=\'available\' where id=$1',[f.destination]),/room amendment/);
    await assert.rejects(db.query("update rooms set room_number='Changed' where id=$1",[f.r2]),/room amendment/);
    await assert.rejects(db.query("update tenant_contracts set status='expired' where id=$1",[f.contract]),/pending room amendment/);
    await assert.rejects(db.query('insert into move_out_cases(tenant_id) values($1)',[f.tenant]),/pending room amendment/);
  });
  await check('tenant signatures are tied to the exact amendment and await owner verification',async()=>{
    await actor(f.tenant,'tenant');
    const path=`${t}/signatures/tenant-1.png`;await object(path);
    await assert.rejects(db.query('select sign_room_transfer($1,$2,$3,$4,$5)',[t,'tenant',path,signatureHash,'c'.repeat(64)]),/Review the current amendment/);
    await sign(t,'tenant');
    assert.equal((await row("select status from room_transfer_signers where transfer_id=$1 and signer_role='tenant'",[t])).status,'signed');
    await actor(owner,'owner');
    await assert.rejects(db.query('select complete_room_transfer($1)',[t]),/Every required/);
    await verify(t);await sign(t,'lessor');
  });
  await check('completion moves the tenant once, retains signed terms and releases the reservation',async()=>{
    await db.query('select complete_room_transfer($1)',[t]);await db.query('select complete_room_transfer($1)',[t]);
    assert.equal((await transfer(t)).status,'completed');
    const active=await row("select count(*)::int n,max(bed_space_id::text) bed from tenant_assignments where tenant_id=$1 and status='active'",[f.tenant]);
    assert.equal(active.n,1);assert.equal(active.bed,f.destination);
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.assignment])).status,'ended');
    assert.equal((await row('select status from bed_spaces where id=$1',[f.destination])).status,'available');
    assert.deepEqual(await row('select to_jsonb(c) snapshot from tenant_contracts c where id=$1',[f.contract]),original);
    await assert.rejects(db.query("select cancel_room_transfer($1,'Undo')",[t]),/Completed transfers/);
  });
  await check('future transfers cannot complete early and cancellation frees only the destination',async()=>{
    const f=await fixture(), tomorrow=(await row("select ((now() at time zone 'Asia/Manila')::date+1)::text d")).d;
    const t=await propose(f,tomorrow);await publish(t);await actor(f.tenant,'tenant');await sign(t,'tenant');
    await actor(owner,'owner');await verify(t);await sign(t,'lessor');
    await assert.rejects(db.query('select complete_room_transfer($1)',[t]),/date has not arrived/);
    await db.query("select cancel_room_transfer($1,'Tenant declined the move')",[t]);
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.assignment])).status,'active');
    assert.equal((await row('select status from bed_spaces where id=$1',[f.destination])).status,'available');
    await assert.rejects(sign(t,'lessor'),/no longer editable/);
    assert.ok(await propose(f));
  });
  await check('required guardian and witness signatures cannot be skipped',async()=>{
    const f=await fixture({guardianRequired:true,witnessRequired:true}), t=await propose(f);await publish(t);
    await actor(f.tenant,'tenant');await sign(t,'tenant');await actor(owner,'owner');await verify(t);await sign(t,'lessor');
    await assert.rejects(db.query('select complete_room_transfer($1)',[t]),/Every required/);
    await actor(guardian,'guardian');await sign(t,'guardian');await actor(owner,'owner');await verify(t,'guardian');
    await sign(t,'witness','Witness Person');await db.query('select complete_room_transfer($1)',[t]);
  });
  await check('strangers, caretakers and anonymous actors cannot propose or confirm',async()=>{
    for(const [uid,role] of [[stranger,'tenant'],[caretaker,'caretaker'],['','']]){
      await actor(uid,role);await assert.rejects(propose(f),/Owner access/);
      await assert.rejects(db.query('select complete_room_transfer($1)',[t]),/Owner access/);
      await assert.rejects(sign(t,'tenant'),/Signer access denied/);
    }
    await actor(owner,'owner');
  });
  await check('RLS limits history to staff, the tenant and linked guardians; direct writes are revoked',async()=>{
    await db.exec('set role authenticated');
    await actor(stranger,'tenant');assert.equal((await row('select count(*)::int n from room_transfers')).n,0);
    await actor(f.tenant,'tenant');assert.equal((await row('select count(*)::int n from room_transfers')).n,1);
    await assert.rejects(db.query("update room_transfers set status='completed'"),/permission denied/);
    await db.exec('reset role');await actor(owner,'owner');
  });
  await check('initial assignments without an active contract still work',async()=>{
    const f=await fixture();await db.query("update tenant_contracts set status='expired' where id=$1",[f.contract]);
    await db.query('select assign_tenant_bed($1,$2)',[f.tenant,f.destination]);
    assert.equal((await row("select bed_space_id from tenant_assignments where tenant_id=$1 and status='active'",[f.tenant])).bed_space_id,f.destination);
  });
  await check('rejected signatures can be resubmitted while previous evidence remains protected',async()=>{
    const f=await fixture({guardianRequired:true}),t=await propose(f);await publish(t);
    await actor(guardian,'guardian');await sign(t,'guardian');
    const old=await row("select id,signature_path from room_transfer_signers where transfer_id=$1 and signer_role='guardian'",[t]);
    await actor(owner,'owner');await db.query("select review_room_transfer_signature($1,false,'Please submit a clear signature')",[old.id]);
    await actor(guardian,'guardian');await sign(t,'guardian');
    assert.equal((await row('select count(*)::int n from room_transfer_signature_events where signer_id=$1',[old.id])).n,3);
    await actor(owner,'owner');await db.query('delete from guardian_tenant_links where tenant_id=$1',[f.tenant]);
    await db.exec('set role authenticated');await actor(guardian,'guardian');
    await db.query('delete from storage.objects where name=$1',[old.signature_path]);
    await db.exec('reset role');await actor(owner,'owner');
    assert.equal((await row('select count(*)::int n from storage.objects where name=$1',[old.signature_path])).n,1);
  });
  await check('unavailable destinations, changed consent and missing signature files are rejected',async()=>{
    const f=await fixture();await db.query("update rooms set is_active=false where id=$1",[f.r2]);
    await assert.rejects(propose(f),/Archived rooms/);
    await db.query("update rooms set is_active=true where id=$1",[f.r2]);
    const t=await propose(f);await publish(t);await actor(f.tenant,'tenant');
    await assert.rejects(db.query('select sign_room_transfer($1,$2,$3,$4,$5)',
      [t,'tenant',`${t}/signatures/tenant-missing.png`,signatureHash,hash]),/Upload a signature/);
    await actor(owner,'owner');
    const other=await fixture();await assert.rejects(db.query('select propose_room_transfer($1,$2,current_date,$3)',
      [other.tenant,f.destination,'Another tenant']),/destination bed is unavailable/);
  });
  await check('new signer requirements cannot be bypassed by an earlier amendment',async()=>{
    const f=await fixture(),t=await propose(f);await publish(t);await actor(f.tenant,'tenant');await sign(t,'tenant');
    await actor(owner,'owner');await verify(t);await sign(t,'lessor');
    await db.query("insert into contract_signers values($1,'guardian',true)",[f.contract]);
    await assert.rejects(db.query('select complete_room_transfer($1)',[t]),/Required contract signers changed/);
    assert.equal((await row('select status from tenant_assignments where id=$1',[f.assignment])).status,'active');
  });
  await check('a later transfer uses the current assignment and keeps earlier signed history',async()=>{
    const second=await propose({...f,destination:f.sourceBed});await publish(second);
    await actor(f.tenant,'tenant');await sign(second,'tenant');await actor(owner,'owner');await verify(second);await sign(second,'lessor');
    await db.query('select complete_room_transfer($1)',[second]);
    assert.equal((await transfer(t)).status,'completed');
    assert.equal((await row("select bed_space_id from tenant_assignments where tenant_id=$1 and status='active'",[f.tenant])).bed_space_id,f.sourceBed);
    assert.equal((await row('select count(*)::int n from room_transfers where tenant_id=$1',[f.tenant])).n,2);
  });
  console.log(`${passed} room transfer PostgreSQL checks passed.`);
}catch(e){console.error(e.message,e.where??'',e.query??'');process.exitCode=1;}
finally{await db.close();}
