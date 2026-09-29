-- PostgREST clients may represent an omitted insert field as SQL NULL, which
-- does not invoke a column default. Generate the identifier in a BEFORE
-- trigger as well so every contract creation path receives a valid number.
create or replace function public.ensure_tenant_contract_number()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if nullif(btrim(new.contract_number), '') is null then
    if tg_op = 'UPDATE' and old.contract_number is not null then
      new.contract_number := old.contract_number;
    else
      new.contract_number := public.next_tenant_contract_number();
    end if;
  else
    new.contract_number := btrim(new.contract_number);
  end if;
  return new;
end;
$$;
drop trigger if exists tenant_contracts_ensure_contract_number
  on public.tenant_contracts;
create trigger tenant_contracts_ensure_contract_number
before insert or update of contract_number on public.tenant_contracts
for each row execute function public.ensure_tenant_contract_number();
-- Repair legacy blank identifiers, if any. A true NULL cannot currently exist
-- because the column is NOT NULL, but this remains safe if older deployments
-- temporarily relaxed that constraint.
update public.tenant_contracts
set contract_number = public.next_tenant_contract_number()
where contract_number is null or btrim(contract_number) = '';
alter table public.tenant_contracts
  alter column contract_number set default public.next_tenant_contract_number(),
  alter column contract_number set not null;
revoke all on function public.ensure_tenant_contract_number()
  from public, anon, authenticated;
