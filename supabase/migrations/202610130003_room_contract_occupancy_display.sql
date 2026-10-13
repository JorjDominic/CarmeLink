-- Read-only room projections of Phase 2 records. No new occupancy state or financial writes.
begin;
create function public.get_room_contract_occupancies(
  p_room_id uuid default null, p_include_history boolean default false
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_owner boolean; v_result jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Staff room access required';
  end if;
  v_owner := public.current_user_role()::text is not distinct from 'owner';
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'id',g.id,'room_id',g.room_id,'mode',g.snapshot->>'mode',
    'released',g.released,'created_at',g.created_at,
    'starts_on',g.snapshot->>'starts_on','ends_on',g.snapshot->>'ends_on',
    'total_rent_cents',case when v_owner then g.snapshot->'total_rent_cents' end,
    'members',(select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'tenant_id',m.value->>'tenant_id','name',m.value->>'name',
      'bed_id',m.value->>'bed_id','bed_label',m.value->>'bed_label',
      'contract_id',c.id,'contract_number',c.contract_number,'status',c.status,
      'rent_cents',case when v_owner then to_jsonb(c.monthly_rent*100) end
    )) order by m.value->>'tenant_id'),'[]'::jsonb)
    from jsonb_array_elements(g.snapshot->'members') m
    left join public.tenant_contracts c on c.occupancy_id=g.id
      and c.tenant_id=(m.value->>'tenant_id')::uuid)
  )) order by g.created_at desc,g.id),'[]'::jsonb) into v_result
  from public.contract_occupancy_arrangements g
  where (p_room_id is null or g.room_id=p_room_id)
    and (coalesce(p_include_history,false) or not g.released);
  return v_result;
end $$;
revoke all on function public.get_room_contract_occupancies(uuid,boolean) from public,anon;
grant execute on function public.get_room_contract_occupancies(uuid,boolean) to authenticated;

-- Reuse the existing RLS-protected rooms realtime channel. Never publish group
-- snapshots/deposit_terms or broaden contract SELECT policies for caretakers.
create function public.refresh_room_contract_display() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_room uuid;
begin
  if tg_table_name='contract_occupancy_arrangements' then
    v_room:=new.room_id;
  elsif new.occupancy_id is not null then
    select room_id into v_room from public.contract_occupancy_arrangements where id=new.occupancy_id;
  end if;
  if v_room is not null then
    perform public.lock_contract_occupancy_room(v_room);
    update public.rooms set updated_at=clock_timestamp() where id=v_room;
  end if;
  return new;
end $$;
revoke all on function public.refresh_room_contract_display() from public,anon,authenticated;
create trigger room_occupancy_display_changed after insert or update of released
  on public.contract_occupancy_arrangements for each row execute function public.refresh_room_contract_display();
create trigger room_contract_display_changed after update of status
  on public.tenant_contracts for each row when (old.status is distinct from new.status)
  execute function public.refresh_room_contract_display();
commit;
