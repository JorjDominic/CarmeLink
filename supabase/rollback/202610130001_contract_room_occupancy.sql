-- Manual rollback only. Never erase real occupancy agreements or signed history.
begin;
do $$ begin
  if exists(select 1 from public.contract_occupancy_arrangements) then
    raise exception 'Rollback blocked: occupancy records exist. Restore application compatibility and preserve data; do not drop contractual history.';
  end if;
end $$;
drop trigger aa_contract_occupancy_assignment on public.tenant_assignments;
drop trigger aa_contract_occupancy_terms on public.tenant_contracts;
drop trigger contract_occupancy_release on public.tenant_contracts;
drop trigger contract_occupancy_room_metadata on public.rooms;
drop trigger contract_occupancy_bed_metadata on public.bed_spaces;
drop trigger group_occupancy_room_transfer on public.room_transfers;
drop function public.guard_group_room_transfer();
drop function public.prepare_contract_occupancy(uuid,text,numeric,jsonb,date,date,text);
drop function public.guard_contract_occupancy_assignment();
drop function public.guard_contract_occupancy_terms();
drop function public.release_contract_occupancy();
drop function public.guard_occupancy_room_metadata();
drop function public.guard_occupancy_bed_metadata();
alter table public.tenant_contracts drop column occupancy_snapshot, drop column occupancy_id;
drop table public.contract_occupancy_arrangements;
create or replace function public.get_my_contract()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if public.current_user_role() <> 'tenant' then
    raise exception 'Tenant access required';
  end if;
  select jsonb_build_object(
    'id', c.id, 'tenant_id', c.tenant_id,
    'contract_number', c.contract_number, 'starts_on', c.starts_on,
    'ends_on', c.ends_on, 'monthly_rent', c.monthly_rent,
    'security_deposit', c.security_deposit, 'status', c.status,
    'notes', c.notes, 'signature_status', c.signature_status,
    'created_at', c.created_at, 'updated_at', c.updated_at,
    'profiles', jsonb_build_object('full_name', p.full_name)
  ) into v_result
  from public.tenant_contracts c
  join public.profiles p on p.id = c.tenant_id
  where c.tenant_id = auth.uid() and c.status in ('draft', 'active')
  order by case when c.status = 'active' then 0 else 1 end, c.starts_on desc
  limit 1;
  return v_result;
end $$;
commit;
