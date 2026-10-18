import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';

export async function checkStandardSharedTransferGuards({db,check,room,prepare,resize,approve,actor,owner,original}) {
  const one=async(sql,args=[])=>(await db.query(sql,args)).rows[0];
  await actor(db,owner);
  await db.exec(readFileSync('supabase/migrations/202610190001_allow_standard_shared_room_transfer.sql','utf8'));
  await db.exec(readFileSync('supabase/migrations/202610190005_preserve_standard_shared_transfer_guards.sql','utf8'));
  let active,source,destination,assignment;
  await check('Standard Shared transfer proposal is allowed while direct unsigned reassignment stays blocked',async()=>{
    source=await room();destination=await room();active=await prepare(source,'standard_shared');
    await approve(db,active.ids[0]);await db.query('select activate_tenant_contract($1)',[active.ids[0]]);
    assignment=(await one("select id from tenant_assignments where tenant_id=$1 and status='active'",[active.members[0].tenant_id])).id;
    await db.query('insert into room_transfers(id,contract_id,tenant_id) values($1,$2,$3)',[randomUUID(),active.ids[0],active.members[0].tenant_id]);
    await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[active.members[0].tenant_id,destination.beds[0].id]),/signed room amendment/);
  });
  await check('occupancy assignment history remains protected and inactive history can be recorded',async()=>{
    await assert.rejects(db.query('delete from tenant_assignments where id=$1',[assignment]),/Preserve occupancy assignment history/);
    const ended=await one("insert into tenant_assignments(tenant_id,bed_space_id,status) values($1,$2,'ended') returning id",[active.members[0].tenant_id,destination.beds[0].id]);
    assert.ok(ended.id);
    assert.equal((await one('select status from tenant_assignments where id=$1',[assignment])).status,'active');
  });
  await check('retired beds continue to reject new assignments',async()=>{
    const r=await room();await resize(r,3);
    const retired=await one('select id from bed_spaces where room_id=$1 and retired_at is not null',[r.id]);
    assert.ok(retired);
    const newcomer=randomUUID();await db.query("insert into profiles values($1,'tenant','New resident',now())",[newcomer]);
    await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[newcomer,retired.id]),/Retired beds/);
  });
  await check('Standard Shared reservations still reject undeclared tenants',async()=>{
    const r=await room();await prepare(r,'standard_shared');
    const newcomer=randomUUID();await db.query("insert into profiles values($1,'tenant','Unlisted resident',now())",[newcomer]);
    await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[newcomer,r.beds[1].id]),/Prepare an individual Standard Shared contract/);
  });
  await check('shared-rent tenants cannot use ordinary cross-room assignment',async()=>{
    const legacyShared=await one('select tenant_id from tenant_contracts where id=$1',[original.sharedContracts[0]]);
    const r=await room(),c=await prepare(r,'exclusive_shared',2);
    for(const tenantId of [legacyShared.tenant_id,c.members[0].tenant_id]) {
      await assert.rejects(db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[tenantId,destination.beds[1].id]),/Occupancy changes require an approved group amendment/);
    }
  });
}
