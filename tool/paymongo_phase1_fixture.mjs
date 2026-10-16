// Isolated fixture: real gateway/ledger SQL, stubbed identity and notification transport.
import {readFileSync} from 'node:fs';
export const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
export const owner=id(1),tenant=id(2),otherTenant=id(3),caretaker=id(4);
export const source=name=>readFileSync(`supabase/migrations/${name}`,'utf8').replaceAll('\r\n','\n');
export async function bootstrapPaymongoFixture(db) {
  await db.exec(`
    do $$begin if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if; if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if; if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role bypassrls;end if;end$$;
    create schema auth;
    create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
    create function auth.role() returns text language sql as $$select coalesce(nullif(current_setting('test.jwtrole',true),''),'authenticated')$$;
    create table profiles(id uuid primary key,full_name text,role text);
    insert into profiles values('${owner}','Owner','owner'),('${tenant}','Sample tenant','tenant'),
      ('${otherTenant}','Other tenant','tenant'),('${caretaker}','Caretaker','caretaker');
    create function current_user_role() returns text language sql security definer as $$select role from public.profiles where id=auth.uid()$$;
    create function is_staff() returns boolean language sql security definer as $$select coalesce(public.current_user_role() in ('owner','caretaker'),false)$$;
    create table tenant_contracts(id uuid primary key,monthly_rent numeric,security_deposit numeric);
    create table guardian_tenant_links(guardian_id uuid,tenant_id uuid);
    create table fixture_notifications(event_key text primary key,title text,body text);
    create table fixture_failures(notifications boolean default false);
    insert into fixture_failures values(false);
    create function emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer) returns void language plpgsql as $$begin
      if (select notifications from public.fixture_failures) then raise exception 'Notification transport unavailable'; end if;
      insert into public.fixture_notifications values($7||':staff',$2,$3) on conflict do nothing; end$$;
    create function emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer) returns void language plpgsql as $$begin
      if (select notifications from public.fixture_failures) then raise exception 'Notification transport unavailable'; end if;
      insert into public.fixture_notifications values($10||':tenant',$5,$6) on conflict do nothing; end$$;
  `);
  const base=source('202609200001_contract_billing_synchronization.sql');
  await db.exec(base.slice(base.indexOf('create table public.billing_charges'),base.indexOf('-- Preserve every legacy invoice')));
  await db.exec(base.slice(base.indexOf('create or replace function public.validate_payment_transaction'),base.indexOf('create or replace view public.billing_charge_summaries')));
  await db.exec(`alter table billing_charges add column notes text;
    alter table payment_transactions add column received_on date;
    alter table payment_transactions drop constraint payment_transactions_payment_method_check;
    create table rent_charge_adjustments(charge_id uuid,amount_delta numeric);
    create table billing_charge_actions(charge_id uuid,amount_delta numeric,deposit_deduction_id uuid,new_due_date date,action_type text,created_at timestamptz default now());
    create table dormitory_options(group_key text,code text,label text,is_active boolean default true);
    insert into dormitory_options values('payment_method','Cash','Cash',true);
  `);
  const view=source('202610130004_payment_verification_charge_categories.sql');
  await db.exec(view.slice(view.indexOf('create or replace view'),view.indexOf('create or replace function')));
  await db.exec(source('202610080003_owner_payment_mode.sql'));
  await db.exec(source('202610080004_paymongo_qr_payments.sql'));
  await db.exec(source('202610110001_demo_test_payment_credits.sql'));
  await db.exec(source('202610120001_paymongo_advance_rent.sql'));
  await db.exec(source('202610160002_paymongo_test_isolation_and_receipts.sql'));
  await db.exec(`grant usage on schema public,auth to authenticated,service_role;
    grant select on profiles,guardian_tenant_links,rent_charge_adjustments,billing_charge_actions,billing_charge_summaries to authenticated;
    grant all on all tables in schema public to service_role;
    grant all on all sequences in schema public to service_role;`);
}
