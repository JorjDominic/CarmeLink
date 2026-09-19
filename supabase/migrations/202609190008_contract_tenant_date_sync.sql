-- Keep the legacy tenant detail date summary synchronized with the active
-- contract while the contract register remains the source of truth.
create or replace function public.validate_contract_tenant()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = new.tenant_id and role = 'tenant'
  ) then
    raise exception 'Contracts may only be assigned to tenant accounts';
  end if;
  return new;
end;
$$;

create trigger tenant_contracts_validate_tenant
before insert or update of tenant_id on public.tenant_contracts
for each row execute function public.validate_contract_tenant();

create or replace function public.sync_active_contract_dates()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_old_tenant uuid := case when tg_op = 'INSERT' then null else old.tenant_id end;
  v_new_tenant uuid := case when tg_op = 'DELETE' then null else new.tenant_id end;
begin
  if v_old_tenant is not null then
    update public.tenant_details d
    set contract_starts_on = c.starts_on, contract_ends_on = c.ends_on
    from (
      select starts_on, ends_on from public.tenant_contracts
      where tenant_id = v_old_tenant and status = 'active'
      limit 1
    ) c where d.profile_id = v_old_tenant;
    if not exists (
      select 1 from public.tenant_contracts
      where tenant_id = v_old_tenant and status = 'active'
    ) then
      update public.tenant_details set contract_starts_on = null,
        contract_ends_on = null where profile_id = v_old_tenant;
    end if;
  end if;

  if v_new_tenant is not null then
    if new.status = 'active' then
      update public.tenant_details set contract_starts_on = new.starts_on,
        contract_ends_on = new.ends_on where profile_id = v_new_tenant;
    elsif not exists (
      select 1 from public.tenant_contracts
      where tenant_id = v_new_tenant and status = 'active'
    ) then
      update public.tenant_details set contract_starts_on = null,
        contract_ends_on = null where profile_id = v_new_tenant;
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger tenant_contracts_sync_tenant_dates
after insert or update or delete on public.tenant_contracts
for each row execute function public.sync_active_contract_dates();

revoke all on function public.validate_contract_tenant() from public, anon, authenticated;
revoke all on function public.sync_active_contract_dates() from public, anon, authenticated;
