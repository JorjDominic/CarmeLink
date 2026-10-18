-- Same-bed renewals for independently priced contracts. Preserve original legal
-- snapshots, assignments, billing history and the existing signing/deposit gates.
begin;

-- One initial contract per member; subsequent terms use the unique renewal link.
drop index public.contract_occupancy_one_contract_member;
create unique index contract_occupancy_one_contract_member on public.tenant_contracts(occupancy_id,tenant_id)
  where occupancy_id is not null and previous_contract_id is null;

create or replace function public.renewal_occupancy_snapshot(
  p_snapshot jsonb,p_tenant uuid,p_start date,p_end date,p_rent numeric
) returns jsonb language sql immutable set search_path='' as $$
  select p_snapshot || jsonb_build_object('starts_on',p_start,'ends_on',p_end,
    'total_rent_cents',case when p_snapshot->>'mode'='solo' then to_jsonb(p_rent*100) else p_snapshot->'total_rent_cents' end,
    'members',(select jsonb_agg(case when m->>'tenant_id'=p_tenant::text
      then m||jsonb_build_object('rent_cents',p_rent*100) else m end order by position)
      from jsonb_array_elements(p_snapshot->'members') with ordinality as items(m,position)))
$$;
revoke all on function public.renewal_occupancy_snapshot(jsonb,uuid,date,date,numeric) from public,anon,authenticated;

create or replace function public.guard_contract_occupancy_terms() returns trigger
language plpgsql security definer set search_path='' as $$
declare g public.contract_occupancy_arrangements; m jsonb; v_room uuid;
  p public.tenant_contracts; v_snapshot jsonb;
begin
  if tg_op='DELETE' then
    if old.occupancy_id is not null then raise exception 'Terminate occupancy contracts; preserve their history'; end if;
    return old;
  end if;
  if tg_op='UPDATE' and (new.occupancy_id is distinct from old.occupancy_id or new.occupancy_snapshot is distinct from old.occupancy_snapshot) then
    raise exception 'Occupancy snapshots cannot be replaced'; end if;
  if new.occupancy_id is null then
    -- Existing null-snapshot records remain valid. New initial contracts must
    -- use preparation; legacy renewals keep their existing approved mechanism.
    if tg_op='INSERT' and new.previous_contract_id is null then
      raise exception 'Prepare an occupancy arrangement before creating a new contract'; end if;
    if tg_op='INSERT' and exists(select 1 from public.tenant_contracts c join public.contract_occupancy_arrangements a on a.id=c.occupancy_id where c.tenant_id=new.tenant_id and not a.released) then raise exception 'Tenant belongs to a reserved occupancy arrangement'; end if;
    if new.occupancy_snapshot is not null then raise exception 'Occupancy requires a registered arrangement'; end if;
    if new.previous_contract_id is not null and exists(select 1 from public.tenant_contracts where id=new.previous_contract_id and occupancy_id is not null) then
      raise exception 'Group occupancy renewals require an approved group amendment workflow'; end if;
    return new;
  end if;
  if tg_op='UPDATE' and old.status<>'draft' and new.status='draft' then raise exception 'Activated occupancy contracts cannot reopen as Draft'; end if;
  if tg_op='UPDATE' and (new.tenant_id<>old.tenant_id or new.monthly_rent<>old.monthly_rent
    or new.security_deposit<>old.security_deposit or new.starts_on<>old.starts_on or new.ends_on<>old.ends_on) then
    raise exception 'Occupancy contractual terms are immutable; use an approved amendment'; end if;
  select room_id into v_room from public.contract_occupancy_arrangements where id=new.occupancy_id;
  perform public.lock_contract_occupancy_room(v_room);
  select * into g from public.contract_occupancy_arrangements where id=new.occupancy_id;
  if tg_op='INSERT' and g.released then raise exception 'A released occupancy arrangement cannot receive new contracts'; end if;
  v_snapshot := g.snapshot;
  if new.previous_contract_id is not null then
    select * into p from public.tenant_contracts where id=new.previous_contract_id;
    if p.occupancy_id is distinct from new.occupancy_id or p.tenant_id is distinct from new.tenant_id
      or p.occupancy_snapshot->>'mode' not in ('solo','standard_shared') then
      raise exception 'Renewal must retain an independently priced occupancy and tenant'; end if;
    v_snapshot := public.renewal_occupancy_snapshot(p.occupancy_snapshot,new.tenant_id,new.starts_on,new.ends_on,new.monthly_rent);
    if new.security_deposit is distinct from p.security_deposit then raise exception 'Renewals carry the existing deposit terms'; end if;
    -- A renewal keeps the resident's current bed; it cannot reserve a departed bed.
    if tg_op='INSERT' and not exists(select 1 from public.tenant_assignments a,
      lateral jsonb_array_elements(v_snapshot->'members') x
      where x->>'tenant_id'=new.tenant_id::text and a.tenant_id=new.tenant_id
        and a.bed_space_id=(x->>'bed_id')::uuid and a.status='active') then
      raise exception 'The renewal requires the existing active bed assignment'; end if;
  end if;
  select value into m from jsonb_array_elements(v_snapshot->'members') where value->>'tenant_id'=new.tenant_id::text;
  if m is null or new.occupancy_snapshot is distinct from v_snapshot or new.monthly_rent<>(m->>'rent_cents')::numeric/100
    or new.security_deposit<>(g.deposit_terms->>new.tenant_id::text)::numeric
    or new.starts_on<>(v_snapshot->>'starts_on')::date or new.ends_on<>(v_snapshot->>'ends_on')::date then raise exception 'Contract must match confirmed occupancy terms'; end if;
  if new.status='active' and (tg_op='INSERT' or old.status<>'active') then
    if tg_op='INSERT' or old.status<>'draft' or g.released then raise exception 'Only reserved draft occupancy contracts can activate'; end if;
    if not exists(select 1 from public.rooms where id=g.room_id and is_active and capacity>=(g.snapshot->>'capacity')::integer) then
      raise exception 'Room capacity or availability changed'; end if;
    if exists(select 1 from jsonb_array_elements(v_snapshot->'members') x where
      (new.previous_contract_id is null or x->>'tenant_id'=new.tenant_id::text) and not exists(
      select 1 from public.tenant_assignments a where a.tenant_id=(x->>'tenant_id')::uuid
        and a.bed_space_id=(x->>'bed_id')::uuid and a.status='active')) then
      raise exception 'Confirmed occupant assignments changed; activation requires group review'; end if;
    if new.previous_contract_id is null and g.snapshot->>'mode'<>'standard_shared' and exists(select 1 from public.tenant_contracts where occupancy_id=g.id and status in ('expired','terminated')) then
      raise exception 'A group contract ended; review occupancy before activation'; end if;
  end if;
  return new;
end $$;

create or replace function public.renew_tenant_contract(
  p_previous_contract_id uuid, p_starts_on date, p_ends_on date,
  p_monthly_rent numeric, p_notes text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare p public.tenant_contracts; c public.tenant_contracts; v_id uuid; v_snapshot jsonb; v_room uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Owner access required';
  end if;
  select * into p from public.tenant_contracts where id=p_previous_contract_id;
  if not found then raise exception 'Previous contract not found'; end if;
  if p.occupancy_id is not null then
    select room_id into v_room from public.contract_occupancy_arrangements where id=p.occupancy_id;
    perform public.lock_contract_occupancy_room(v_room);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p.tenant_id::text,493));
  select * into p from public.tenant_contracts where id=p_previous_contract_id for update;
  if p.status not in ('active','expired') then raise exception 'Only an active or expired contract can be renewed'; end if;
  if p_starts_on is null or p_ends_on is null or p_starts_on <= p.ends_on or p_ends_on < p_starts_on then
    raise exception 'Enter a valid renewal period after the previous contract ends';
  end if;
  if p_monthly_rent is null or p_monthly_rent::text in ('NaN','Infinity','-Infinity')
    or p_monthly_rent < 0 or p_monthly_rent > 9999999999.99
    or p_monthly_rent <> round(p_monthly_rent,2) then
    raise exception 'Enter a valid monthly rent with at most two decimals';
  end if;
  select * into c from public.tenant_contracts where previous_contract_id=p.id and status <> 'terminated';
  if found then
    if c.status='draft' and c.starts_on=p_starts_on and c.ends_on=p_ends_on
      and c.monthly_rent=p_monthly_rent and c.notes is not distinct from nullif(btrim(p_notes),'') then
      return c.id; -- A retry of the same save does not duplicate a draft.
    end if;
    raise exception 'This contract already has a renewal';
  end if;
  if p.occupancy_id is not null then
    if p.occupancy_snapshot->>'mode' not in ('solo','standard_shared') then
      raise exception 'Exclusive Shared renewals require a group amendment'; end if;
    v_snapshot := public.renewal_occupancy_snapshot(p.occupancy_snapshot,p.tenant_id,p_starts_on,p_ends_on,p_monthly_rent);
  end if;
  insert into public.tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,security_deposit,status,notes,previous_contract_id,occupancy_id,occupancy_snapshot)
  values(p.tenant_id,p_starts_on,p_ends_on,p_monthly_rent,p.security_deposit,'draft',nullif(btrim(p_notes),''),p.id,p.occupancy_id,v_snapshot)
  returning id into v_id;
  return v_id;
end;
$$;

-- Keep one displayed contract per occupant as renewal history grows.
create or replace function public.get_room_contract_occupancies(
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
    'starts_on',coalesce(term.starts_on::text,g.snapshot->>'starts_on'),
    'ends_on',coalesce(term.ends_on::text,g.snapshot->>'ends_on'),
    'total_rent_cents',case when v_owner then coalesce(to_jsonb(term.monthly_rent*100),g.snapshot->'total_rent_cents') end,
    'members',(select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'tenant_id',m.value->>'tenant_id','name',m.value->>'name',
      'bed_id',m.value->>'bed_id','bed_label',m.value->>'bed_label',
      'contract_id',c.id,'contract_number',c.contract_number,'status',c.status,
      'rent_cents',case when v_owner then to_jsonb(c.monthly_rent*100) end
    )) order by m.value->>'tenant_id'),'[]'::jsonb)
    from jsonb_array_elements(g.snapshot->'members') m
    left join lateral (
      select c.* from public.tenant_contracts c where c.occupancy_id=g.id
        and c.tenant_id=(m.value->>'tenant_id')::uuid
      order by case c.status when 'active' then 0 when 'draft' then 1 when 'expired' then 2 else 3 end,
        c.starts_on desc,c.id limit 1
    ) c on true)
  )) order by g.created_at desc,g.id),'[]'::jsonb) into v_result
  from public.contract_occupancy_arrangements g
  left join lateral (
    select c.* from public.tenant_contracts c where c.occupancy_id=g.id
      and g.snapshot->>'mode'='solo'
    order by case c.status when 'active' then 0 when 'draft' then 1 when 'expired' then 2 else 3 end,
      c.starts_on desc,c.id limit 1
  ) term on true
  where (p_room_id is null or g.room_id=p_room_id)
    and (coalesce(p_include_history,false) or not g.released);
  return v_result;
end $$;

commit;
