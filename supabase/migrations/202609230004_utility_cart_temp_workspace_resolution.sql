-- Give PostgreSQL's function validator a typed fallback relation for the
-- transaction-local occupant workspace. At runtime pg_temp is searched first,
-- and the function creates/truncates only its session-local table.
create view public.utility_cart_occupants as
select
  null::uuid as tenant_id,
  null::text as tenant_name,
  null::text as room_number,
  null::text as bed_label
where false;

revoke all on public.utility_cart_occupants from public, anon, authenticated;

alter function public.create_utility_charge_cart(jsonb)
  set search_path = pg_temp, pg_catalog, public;
