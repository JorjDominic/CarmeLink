// Test-only schemas in an empty disposable database. Actual guards come from migrations.
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const source=file=>readFileSync(`supabase/migrations/${file}`,'utf8');
const fn=(file,name)=>{const sql=source(file),a=sql.indexOf(`create or replace function public.${name}(`);assert.ok(a>=0);return sql.slice(a,sql.indexOf('$$;',sql.indexOf('as $$',a)+5)+3);};
export async function bootstrapOccupancyFixture(db,fixture,{stabilize=true}={}) {
  const owner='00000000-0000-0000-0000-000000000001';
  const row=async(sql,p=[]) => (await db.query(sql,p)).rows[0];
  await db.exec(`do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if; if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if; end $$;create schema auth;create schema storage;
    create type app_role as enum('owner','caretaker','tenant','guardian');
    create table profiles(id uuid primary key,role app_role,full_name text,email_verified_at timestamptz);
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create function current_user_role() returns app_role language sql security definer as $$select role from public.profiles where id=auth.uid()$$;
    create function is_staff() returns boolean language sql security definer as $$select coalesce(public.current_user_role() in ('owner','caretaker'),false)$$;
    create table tenant_details(profile_id uuid primary key,contract_starts_on date,contract_ends_on date,
      emergency_contact_name text default 'Parent',emergency_contact_phone text default '09171234567',emergency_contact_relationship text default 'Parent');
    create table contract_requirements(contract_id uuid,is_required boolean,status text);
    create table move_out_cases(contract_id uuid,status text);
    create table contract_signers(contract_id uuid,signer_role text,is_required boolean,status text);
    create table contract_documents(contract_id uuid,document_type text,version integer,review_status text,storage_path text);
    create table storage.objects(bucket_id text,name text);
    create table room_transfers(id uuid,contract_id uuid,source_assignment_id uuid,destination_bed_id uuid,resulting_assignment_id uuid,tenant_id uuid,status text);
    create table billing_charges(id uuid primary key default gen_random_uuid(),contract_id uuid,tenant_id uuid,
      title text,category text,original_amount numeric,due_date date,period_start date,period_end date,source text,
      terms_snapshot jsonb,created_by uuid);
    create unique index billing_period on billing_charges(contract_id,category,period_start) where contract_id is not null;
  `);
  const core=source('202609070002_core_dormitory_structure.sql');
  await db.exec(core.slice(0,core.indexOf('create or replace function public.is_staff')));
  await db.exec('alter table rooms add column is_active boolean default true');
  await db.query("insert into profiles values($1,'owner','Owner',now()),($2,'caretaker','Caretaker',now())",[owner,id(2)]);
  await db.query("select set_config('test.actor',$1,false)",[owner]);
  await db.exec(source('202609190007_contracts_crud.sql'));
  await db.exec(fn('202609070002_core_dormitory_structure.sql','is_guardian_of'));
  for(const [file,policy] of [
    ['202609260005_tenant_electronic_signature.sql','tenant_contracts_tenant_select'],
    ['202609270008_resident_guardian_document_access.sql','tenant_contracts_guardian_select']]) {
    const sql=source(file),start=sql.indexOf(`create policy ${policy}`);
    await db.exec(sql.slice(start,sql.indexOf(';',start)+1));
  }
  await db.exec('grant usage on schema public,auth to authenticated');
  await db.exec("alter table tenant_contracts add column previous_contract_id uuid,add column signature_status text default 'not_generated';alter table tenant_contracts alter column contract_number set default ('CTR-'||gen_random_uuid())");
  await db.exec(source('202609190008_contract_tenant_date_sync.sql'));
  await db.exec(fn('202610090004_contract_renewals.sql','guard_contract_renewal'));
  await db.exec('create trigger tenant_contracts_renewal_guard before insert or update on tenant_contracts for each row execute function guard_contract_renewal()');
  await db.exec(fn('202609260002_onboarding_safety_gates.sql','require_verified_email_for_active_contract'));
  await db.exec('create trigger verified_activation before insert or update on tenant_contracts for each row execute function require_verified_email_for_active_contract()');
  await db.exec(fn('202609190010_contract_document_workflow.sql','protect_contract_after_signature'));
  await db.exec('create trigger protect_signed before update on tenant_contracts for each row execute function protect_contract_after_signature()');
  await db.exec(fn('202610090006_signed_room_transfers.sql','guard_signed_room_assignment'));
  await db.exec('create trigger guard_signed_room_assignment before insert or update or delete on tenant_assignments for each row execute function guard_signed_room_assignment()');
  await db.exec(fn('202610040002_separate_security_deposit_receipts.sql','generate_contract_billing_charges'));
  await db.exec(fn('202609200001_contract_billing_synchronization.sql','sync_contract_billing_on_activation'));
  await db.exec('create trigger generate_billing after insert or update of status on tenant_contracts for each row execute function sync_contract_billing_on_activation()');
  await db.exec(source('202609280007_activate_contract_without_rewriting_terms.sql'));
  await db.exec(source('202610120002_signed_contract_activation.sql'));
  const legacyFixture=await fixture();
  await db.query('insert into tenant_assignments(tenant_id,bed_space_id) values($1,$2)',[legacyFixture.tenants[0],legacyFixture.beds[0]]);
  const legacyContract=await row('insert into tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent) values($1,current_date,current_date+30,2500) returning id',[legacyFixture.tenants[0]]);
  await db.exec(source('202610130001_contract_room_occupancy.sql'));
  await db.exec(readFileSync('supabase/rollback/202610130001_contract_room_occupancy.sql','utf8'));
  await db.exec(source('202610130001_contract_room_occupancy.sql'));
  if (stabilize) await db.exec(source('202610130002_contract_occupancy_stabilization.sql'));
  return {legacyFixture,legacyContract};
}
