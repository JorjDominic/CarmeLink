-- Phase 4 regression: owner-only room expansion, fixed four-bed capacity,
-- archive/reactivate lifecycle, and assignment protection. All writes roll back.
begin;

do $$
declare
  v_owner uuid;
  v_caretaker uuid;
  v_tenant uuid;
  v_room uuid;
  v_bed uuid;
  v_denied boolean := false;
  v_existing_assignment uuid;
begin
  select id into v_owner from public.profiles where role::text = 'owner' limit 1;
  select id into v_caretaker from public.profiles where role::text = 'caretaker' limit 1;
  select id into v_tenant from public.profiles where role::text = 'tenant' limit 1;

  if v_owner is null or v_caretaker is null or v_tenant is null then
    raise exception 'Need owner, caretaker, and tenant fixtures';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  v_room := public.create_room_with_four_beds(
    'QA-PHASE4-' || floor(extract(epoch from clock_timestamp()))::bigint,
    'Third floor',
    'Phase 4 rollback fixture'
  );

  if (select count(*) from public.bed_spaces where room_id = v_room) <> 4 then
    raise exception 'New room did not receive exactly four bed spaces';
  end if;

  update public.rooms set is_active = false where id = v_room;
  if (select is_active from public.rooms where id = v_room) is not false then
    raise exception 'Owner could not archive an empty room';
  end if;

  perform set_config('request.jwt.claim.sub', v_caretaker::text, true);
  begin
    perform public.create_room_with_four_beds(
      'QA-CARETAKER-FORBIDDEN',
      'Third floor',
      'Caretaker must not create structural rooms'
    );
  exception when others then
    if sqlerrm ilike '%only the owner%' or sqlerrm ilike '%row-level security%' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then
    raise exception 'Caretaker created a structural room';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  select id into v_existing_assignment
  from public.tenant_assignments
  where tenant_id = v_tenant and status = 'active'
  limit 1;

  if v_existing_assignment is not null then
    update public.tenant_assignments
    set status = 'ended', ends_on = current_date
    where id = v_existing_assignment;
  end if;

  select id into v_bed
  from public.bed_spaces
  where room_id = v_room
  order by label
  limit 1;

  v_denied := false;
  begin
    insert into public.tenant_assignments(tenant_id, bed_space_id, status)
    values (v_tenant, v_bed, 'active');
  exception when others then
    if sqlerrm ilike '%archived rooms cannot receive assignments%' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then
    raise exception 'Archived room accepted a new active assignment';
  end if;

  execute 'reset role';
  raise notice 'Phase 4 room expansion checks passed';
end
$$;

rollback;
