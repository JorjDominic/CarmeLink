-- Activation changes lifecycle state only. Do not require clients to resend
-- immutable/generated contract terms such as contract_number.
create or replace function public.activate_tenant_contract(p_contract_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract_id uuid;
begin
  if public.current_user_role() <> 'owner' then
    raise exception 'Owner access required';
  end if;

  update public.tenant_contracts
  set status = 'active'
  where id = p_contract_id and status = 'draft'
  returning id into v_contract_id;

  if v_contract_id is null then
    raise exception 'Draft contract not found';
  end if;
  return v_contract_id;
end;
$$;

revoke all on function public.activate_tenant_contract(uuid)
  from public, anon;
grant execute on function public.activate_tenant_contract(uuid)
  to authenticated;

