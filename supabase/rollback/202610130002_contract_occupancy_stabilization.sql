-- Manual reversal of an unused deployment only; keep the stricter Owner check.
begin;
do $$ begin
  if to_regprocedure('public.refresh_room_contract_display()') is not null then
    raise exception 'Reverse the Phase 3 room display migration first.';
  end if;
  if exists(select 1 from public.contract_occupancy_arrangements) then
    raise exception 'Rollback blocked: occupancy records exist; use a forward corrective migration.';
  end if;
end $$;
create or replace function public.prepare_contract_occupancy(
  p_room_id uuid, p_mode text, p_total_rent numeric, p_members jsonb,
  p_starts_on date, p_ends_on date, p_notes text default null
) returns uuid[] language plpgsql security definer set search_path='' as $$
declare r public.rooms; m jsonb; v_members jsonb := '[]'; v_group uuid := gen_random_uuid();
  v_snapshot jsonb; v_deposits jsonb := '{}'; v_ids uuid[] := '{}'; v_id uuid; v_count integer; v_cents bigint; v_share bigint;
  v_tenant uuid; v_bed uuid; v_name text; v_label text; v_deposit numeric; v_index integer := 0;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  if p_members is null or jsonb_typeof(p_members)<>'array' then raise exception 'Select registered occupants'; end if;
  v_count:=jsonb_array_length(p_members);
  if p_mode is null or p_mode not in ('solo','shared') or (p_mode='solo' and v_count<>1)
    or (p_mode='shared' and v_count not between 2 and 4) then raise exception 'Invalid occupancy arrangement'; end if;
  if p_total_rent is null or p_total_rent::text in ('NaN','Infinity','-Infinity') or p_total_rent<0
    or p_total_rent>9999999999.99 or p_total_rent<>round(p_total_rent,2) then raise exception 'Invalid room rent'; end if;
  if p_starts_on is null or p_ends_on is null or p_ends_on<p_starts_on then raise exception 'Invalid contract dates'; end if;
  select * into r from public.rooms where id=p_room_id for update;
  if not found or not r.is_active then raise exception 'Select an active registered room'; end if;
  if v_count>r.capacity then raise exception 'Room capacity exceeded'; end if;
  if exists(select 1 from public.contract_occupancy_arrangements where room_id=r.id and not released) then
    raise exception 'Room already reserved by an occupancy arrangement'; end if;
  if (select count(distinct value->>'tenant_id') from jsonb_array_elements(p_members))<>v_count
    or (select count(distinct value->>'bed_id') from jsonb_array_elements(p_members))<>v_count then
    raise exception 'Duplicate tenant or bed selection'; end if;
  -- Canonical tenant order makes cents allocation repeatable and locks consistent.
  for m in select value from jsonb_array_elements(p_members) order by value->>'tenant_id' loop
    v_tenant:=(m->>'tenant_id')::uuid;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant::text,493));
    perform 1 from public.profiles where id=v_tenant for update;
  end loop;
  if exists(select 1 from public.tenant_assignments a join public.bed_spaces b on b.id=a.bed_space_id
    where a.status='active' and b.room_id=r.id and not exists(select 1 from jsonb_array_elements(p_members) x where x->>'tenant_id'=a.tenant_id::text)) then
    raise exception 'Room has occupants outside the selected arrangement'; end if;
  v_cents:=(p_total_rent*100)::bigint;
  for m in select value from jsonb_array_elements(p_members) order by value->>'tenant_id' loop
    v_tenant:=(m->>'tenant_id')::uuid; v_bed:=(m->>'bed_id')::uuid; v_deposit:=(m->>'security_deposit')::numeric;
    select full_name into v_name from public.profiles where id=v_tenant and role::text='tenant';
    if not found then raise exception 'Select registered tenant profiles'; end if;
    if exists(select 1 from public.tenant_contracts where tenant_id=v_tenant and status in ('draft','active')) then
      raise exception 'Tenant already has a draft or active contract'; end if;
    select label into v_label from public.bed_spaces where id=v_bed and room_id=r.id and status='available' for update;
    if not found then raise exception 'Selected bed is unavailable or belongs to another room'; end if;
    if exists(select 1 from public.tenant_assignments where status='active'
      and (tenant_id=v_tenant or bed_space_id=v_bed) and (tenant_id<>v_tenant or bed_space_id<>v_bed)) then
      raise exception 'Conflicting tenant or bed assignment'; end if;
    if v_deposit is null or v_deposit::text in ('NaN','Infinity','-Infinity') or v_deposit<0
      or v_deposit>9999999999.99 or v_deposit<>round(v_deposit,2) then raise exception 'Invalid individual deposit'; end if;
    v_share:=v_cents/v_count + case when v_index<v_cents%v_count then 1 else 0 end;
    v_members:=v_members||jsonb_build_array(jsonb_build_object('tenant_id',v_tenant,'name',v_name,
      'bed_id',v_bed,'bed_label',v_label,'rent_cents',v_share));
    v_deposits:=v_deposits||jsonb_build_object(v_tenant::text,v_deposit);
    v_index:=v_index+1;
  end loop;
  v_snapshot:=jsonb_build_object('mode',p_mode,'room_id',r.id,'room_number',r.room_number,
    'capacity',r.capacity,'total_rent_cents',v_cents,'starts_on',p_starts_on,'ends_on',p_ends_on,'members',v_members);
  insert into public.contract_occupancy_arrangements(id,room_id,snapshot,deposit_terms) values(v_group,r.id,v_snapshot,v_deposits);
  for m in select value from jsonb_array_elements(v_members) loop
    v_tenant:=(m->>'tenant_id')::uuid; v_bed:=(m->>'bed_id')::uuid;
    -- Existing onboarding assigns beds before generating/signing the lease.
    if not exists(select 1 from public.tenant_assignments where tenant_id=v_tenant and bed_space_id=v_bed and status='active') then
      insert into public.tenant_assignments(tenant_id,bed_space_id) values(v_tenant,v_bed);
    end if;
  end loop;
  for m in select value from jsonb_array_elements(v_members) loop
    v_tenant:=(m->>'tenant_id')::uuid;
    insert into public.tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,security_deposit,status,notes,occupancy_id,occupancy_snapshot)
      values(v_tenant,p_starts_on,p_ends_on,(m->>'rent_cents')::numeric/100,(v_deposits->>v_tenant::text)::numeric,
        'draft',nullif(btrim(p_notes),''),v_group,v_snapshot) returning id into v_id;
    v_ids:=array_append(v_ids,v_id);
  end loop;
  return v_ids;
end $$;

create or replace function public.guard_contract_occupancy_assignment() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_room uuid; v_group public.contract_occupancy_arrangements; v_member jsonb;
begin
  if tg_op='DELETE' then
    if exists(select 1 from public.tenant_contracts where tenant_id=old.tenant_id and occupancy_id is not null) then
      raise exception 'Preserve occupancy assignment history'; end if;
    return old;
  end if;
  if tg_op='UPDATE' and new.status<>'active' then return new; end if;
  if new.status<>'active' then return new; end if;
  select room_id into v_room from public.bed_spaces where id=new.bed_space_id;
  perform 1 from public.rooms where id=v_room for update;
  -- Also lock the tenant across rooms and competing preparations.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.tenant_id::text,493));
  select * into v_group from public.contract_occupancy_arrangements where room_id=v_room and not released;
  if found then
    select value into v_member from jsonb_array_elements(v_group.snapshot->'members')
      where value->>'tenant_id'=new.tenant_id::text and value->>'bed_id'=new.bed_space_id::text;
    if v_member is null then raise exception 'Room reserved by a contract occupancy arrangement'; end if;
    if exists(select 1 from public.tenant_contracts where occupancy_id=v_group.id) and not exists(select 1 from public.tenant_contracts where occupancy_id=v_group.id and tenant_id=new.tenant_id and status in ('draft','active')) then raise exception 'This occupant contract ended; an approved group amendment is required'; end if;
  end if;
  if exists(select 1 from public.tenant_contracts c join public.contract_occupancy_arrangements g on g.id=c.occupancy_id
    where c.tenant_id=new.tenant_id and not g.released and g.room_id<>v_room) then
    raise exception 'Occupancy changes require an approved group amendment'; end if;
  if (select count(*) from public.tenant_assignments a join public.bed_spaces b on b.id=a.bed_space_id
    where a.status='active' and b.room_id=v_room and a.id<>new.id) >= (select capacity from public.rooms where id=v_room) then
    raise exception 'Room capacity exceeded'; end if;
  return new;
end $$;

create or replace function public.guard_contract_occupancy_terms() returns trigger
language plpgsql security definer set search_path='' as $$
declare g public.contract_occupancy_arrangements; m jsonb; v_room uuid;
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
  perform 1 from public.rooms where id=v_room for update;
  select * into g from public.contract_occupancy_arrangements where id=new.occupancy_id;
  if tg_op='INSERT' and g.released then raise exception 'A released occupancy arrangement cannot receive new contracts'; end if;
  select value into m from jsonb_array_elements(g.snapshot->'members') where value->>'tenant_id'=new.tenant_id::text;
  if m is null or new.occupancy_snapshot is distinct from g.snapshot or new.monthly_rent<>(m->>'rent_cents')::numeric/100
    or new.security_deposit<>(g.deposit_terms->>new.tenant_id::text)::numeric
    or new.starts_on<>(g.snapshot->>'starts_on')::date or new.ends_on<>(g.snapshot->>'ends_on')::date then raise exception 'Contract must match confirmed occupancy terms'; end if;
  if new.status='active' and (tg_op='INSERT' or old.status<>'active') then
    if tg_op='INSERT' or old.status<>'draft' or g.released then raise exception 'Only reserved draft occupancy contracts can activate'; end if;
    if not exists(select 1 from public.rooms where id=g.room_id and is_active and capacity>=(g.snapshot->>'capacity')::integer) then
      raise exception 'Room capacity or availability changed'; end if;
    if exists(select 1 from jsonb_array_elements(g.snapshot->'members') x where not exists(
      select 1 from public.tenant_assignments a where a.tenant_id=(x->>'tenant_id')::uuid
        and a.bed_space_id=(x->>'bed_id')::uuid and a.status='active')) then
      raise exception 'Confirmed occupant assignments changed; activation requires group review'; end if;
    if exists(select 1 from public.tenant_contracts where occupancy_id=g.id and status in ('expired','terminated')) then
      raise exception 'A group contract ended; review occupancy before activation'; end if;
  end if;
  return new;
end $$;

create or replace function public.guard_occupancy_bed_metadata() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.rooms where id=old.room_id for update;
  if exists(select 1 from public.contract_occupancy_arrangements where room_id=old.room_id and not released) then
    raise exception 'Cancel or amend the reserved occupancy before editing its beds'; end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;

create or replace function public.activate_tenant_contract(p_contract_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract_id uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
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
drop function public.lock_contract_occupancy_room(uuid);
commit;
