drop view if exists public.utility_cart_occupants;

create unlogged table public.utility_cart_occupants (
  tenant_id uuid,
  tenant_name text,
  room_number text,
  bed_label text
);

alter table public.utility_cart_occupants enable row level security;
revoke all on public.utility_cart_occupants from public, anon, authenticated;

create or replace function public.lock_utility_cart_workspace()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(202609230005);
  return new;
end; $$;

create trigger utility_batches_lock_workspace
before insert on public.utility_charge_batches
for each statement execute function public.lock_utility_cart_workspace();

revoke all on function public.lock_utility_cart_workspace()
  from public, anon, authenticated;

comment on table public.utility_cart_occupants is
  'Internal access-denied transaction workspace; utility cart issuance is serialized by advisory lock.';
