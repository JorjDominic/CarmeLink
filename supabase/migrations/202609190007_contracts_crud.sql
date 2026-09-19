-- Owner-managed tenant contracts. Payments remain separate financial facts and
-- can be linked to contract charges by a later billing synchronization phase.
create table public.tenant_contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  contract_number text not null unique,
  starts_on date not null,
  ends_on date not null,
  monthly_rent numeric(12,2) not null check (monthly_rent >= 0),
  security_deposit numeric(12,2) not null default 0 check (security_deposit >= 0),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'expired', 'terminated')),
  notes text,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint tenant_contract_dates_valid check (ends_on >= starts_on)
);

create index tenant_contracts_tenant_idx
  on public.tenant_contracts(tenant_id, starts_on desc);
create index tenant_contracts_status_end_idx
  on public.tenant_contracts(status, ends_on);
create unique index tenant_contracts_one_active_per_tenant_idx
  on public.tenant_contracts(tenant_id) where status = 'active';

create trigger tenant_contracts_set_updated_at
before update on public.tenant_contracts
for each row execute function public.set_updated_at();

alter table public.tenant_contracts enable row level security;

create policy tenant_contracts_owner_select on public.tenant_contracts
for select to authenticated using ((select public.current_user_role()) = 'owner');
create policy tenant_contracts_owner_insert on public.tenant_contracts
for insert to authenticated with check (
  (select public.current_user_role()) = 'owner' and created_by = auth.uid()
);
create policy tenant_contracts_owner_update on public.tenant_contracts
for update to authenticated
using ((select public.current_user_role()) = 'owner')
with check ((select public.current_user_role()) = 'owner');
create policy tenant_contracts_owner_delete on public.tenant_contracts
for delete to authenticated using ((select public.current_user_role()) = 'owner');

grant select, insert, update, delete on public.tenant_contracts to authenticated;
revoke all on public.tenant_contracts from anon;

comment on table public.tenant_contracts is
  'Versioned owner-managed tenant contracts; financial transactions are stored separately.';
