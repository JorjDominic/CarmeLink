// Test fixture only; real lifecycle, contract, signing and billing guards come from migrations.
import { readFileSync } from 'node:fs';
import { bootstrapOccupancyFixture } from './contract_occupancy_test_fixture.mjs';
export const source = name => readFileSync(`supabase/migrations/${name}`, 'utf8').replaceAll('\r\n','\n');
export const owner = '00000000-0000-0000-0000-000000000001';
export const actor = (db, who = owner) => db.query("select set_config('test.actor',$1,false)",[who]);
export async function bootstrapRoomCapacity(db, { randomUUID }) {
  const legacy = async () => {
    const room=randomUUID(),tenants=[],beds=[];
    await db.query("insert into rooms(id,room_number,floor,capacity) values($1::uuid,$1::text,'Ground',4)",[room]);
    for(let n=1;n<=4;n++) {
      const tenant=randomUUID(),bed=randomUUID(); tenants.push(tenant);beds.push(bed);
      await db.query("insert into profiles values($1,'tenant','Legacy tenant',now())",[tenant]);
      await db.query('insert into tenant_details(profile_id) values($1)',[tenant]);
      await db.query("insert into bed_spaces(id,room_id,label) values($1,$2,$3)",[bed,room,`Bed ${n}`]);
    }
    return {room,tenants,beds};
  };
  const original=await bootstrapOccupancyFixture(db,legacy);
  await db.exec(source('202609100002_complete_tenant_directory.sql'));
  const sharedRoom=await legacy();
  const sharedContracts=(await db.query("select prepare_contract_occupancy($1,'shared',6000,$2::jsonb,current_date,current_date+30) ids",[sharedRoom.room,JSON.stringify(sharedRoom.tenants.slice(0,2).map((tenant,i)=>({tenant_id:tenant,bed_id:sharedRoom.beds[i],security_deposit:1500})))])).rows[0].ids;
  for(const id of sharedContracts) {await approve(db,id);await db.query('select activate_tenant_contract($1)',[id]);}
  const sharedHistory=(await db.query('select id,occupancy_snapshot,monthly_rent,security_deposit,status from tenant_contracts where id=any($1::uuid[]) order by id',[sharedContracts])).rows;
  await db.exec(`create function is_owner() returns boolean language sql security definer set search_path='' as $$select coalesce(public.current_user_role()::text='owner',false)$$;
    alter table rooms add column layout_number text,add column layout_floor text;
    create table maintenance_reports(id uuid primary key,room_id uuid references rooms,location text);`);
  await db.exec(source('202610070009_room_expansion_and_dynamic_capacity.sql'));
  const safety=source('202610090002_phase3_report_and_room_safety.sql');
  for(const name of ['assert_room_has_no_dependencies','protect_room_lifecycle','protect_fixed_room_beds']) {
    const start=safety.indexOf(`create or replace function public.${name}(`);
    await db.exec(safety.slice(start,safety.indexOf('$$;',start)+3));
  }
  await db.exec(source('202610160004_dynamic_physical_room_capacity.sql'));
  await db.exec(source('202610160005_standard_shared_contract_occupancy.sql'));
  await db.exec(source('202610130003_room_contract_occupancy_display.sql'));
  return {...original,sharedContracts,sharedHistory};
}
export async function approve(db, id) {
  await db.query("insert into contract_signers values($1,'tenant',true,'verified'),($1,'lessor',true,'verified')",[id]);
  await db.query("insert into contract_requirements values($1,true,'verified')",[id]);
  await db.query("insert into contract_documents values($1::uuid,'generated',1,'not_required',$1::text||'/original'),($1::uuid,'signed',1,'verified',$1::text||'/signed')",[id]);
  await db.query("insert into storage.objects values('contract-documents',$1::text||'/signed')",[id]);
  await db.query("update tenant_contracts set signature_status='verified' where id=$1",[id]);
}
