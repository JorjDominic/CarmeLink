-- A signed solo transfer moves the live room reservation, not the signed lease.
-- Reconcile already completed moves only when the current assignment is safe.
begin;
create table public.solo_occupancy_relocations (
  id uuid primary key default gen_random_uuid(),
  occupancy_id uuid not null references public.contract_occupancy_arrangements(id) on delete restrict,
  transfer_id uuid not null unique references public.room_transfers(id) on delete restrict,
  source_room_id uuid not null references public.rooms(id) on delete restrict,
  destination_room_id uuid not null references public.rooms(id) on delete restrict,
  previous_snapshot jsonb not null,
  current_snapshot jsonb not null,
  applied_at timestamptz not null default now()
);
alter table public.solo_occupancy_relocations enable row level security;
-- History is exposed only by the staff projection, which redacts rental amounts.
revoke all on public.solo_occupancy_relocations from public,anon,authenticated;

create or replace function public.guard_group_room_transfer() returns trigger
language plpgsql security definer set search_path='' as $$
declare g public.contract_occupancy_arrangements; v_destination uuid;
begin
  select a.* into g from public.contract_occupancy_arrangements a
    join public.tenant_contracts c on c.occupancy_id=a.id where c.id=new.contract_id;
  if g.snapshot->>'mode' in ('shared','exclusive_shared') then
    raise exception 'Group occupancy room changes require an approved group amendment workflow';
  end if;
  if g.snapshot->>'mode'='solo' then
    select room_id into v_destination from public.bed_spaces where id=new.destination_bed_id;
    perform public.lock_contract_occupancy_room(v_destination);
    if exists(select 1 from public.tenant_assignments a join public.bed_spaces b on b.id=a.bed_space_id
      where a.status='active' and b.room_id=v_destination and a.tenant_id<>new.tenant_id)
      or exists(select 1 from public.contract_occupancy_arrangements a
        where a.room_id=v_destination and not a.released and a.id<>g.id)
      or exists(select 1 from public.room_transfers t join public.bed_spaces b on b.id=t.destination_bed_id
        where t.id<>new.id and t.status in ('draft','awaiting_signatures') and b.room_id=v_destination) then
      raise exception 'Solo occupancy requires an empty destination room without another reservation';
    end if;
  end if;
  return new;
end $$;
create trigger check_solo_room_transfer_completion before update of status on public.room_transfers
  for each row when(new.status='completed' and old.status is distinct from 'completed')
  execute function public.guard_group_room_transfer();

create or replace function public.relocate_completed_solo_occupancy(p_transfer_id uuid,p_strict boolean default true)
returns boolean language plpgsql security definer set search_path='' as $$
declare t public.room_transfers; c public.tenant_contracts; g public.contract_occupancy_arrangements;
  b public.bed_spaces; r public.rooms; v_previous jsonb; v_current jsonb; v_room uuid;
begin
  select * into t from public.room_transfers where id=p_transfer_id and status='completed';
  if not found then return false; end if;
  select * into c from public.tenant_contracts where id=t.contract_id;
  select * into g from public.contract_occupancy_arrangements where id=c.occupancy_id;
  if g.id is null or g.snapshot->>'mode' is distinct from 'solo' or g.released then return false; end if;
  -- Never replay an older move over a more recent active assignment.
  if not exists(select 1 from public.tenant_assignments where id=t.resulting_assignment_id
    and tenant_id=t.tenant_id and bed_space_id=t.destination_bed_id and status='active') then return false; end if;
  select * into b from public.bed_spaces where id=t.destination_bed_id;
  for v_room in select distinct x from unnest(array[g.room_id,b.room_id]) x order by x loop
    perform public.lock_contract_occupancy_room(v_room);
  end loop;
  select * into g from public.contract_occupancy_arrangements where id=g.id for update;
  select * into r from public.rooms where id=b.room_id;
  if g.room_id=b.room_id and exists(select 1 from jsonb_array_elements(g.snapshot->'members') m
    where m->>'tenant_id'=t.tenant_id::text and m->>'bed_id'=b.id::text) then return true; end if;
  if not coalesce(r.is_active,false) or b.retired_at is not null
    or jsonb_array_length(g.snapshot->'members')<>1
    or exists(select 1 from public.tenant_assignments a join public.bed_spaces bs on bs.id=a.bed_space_id
      where a.status='active' and bs.room_id=b.room_id and a.tenant_id<>t.tenant_id)
    or exists(select 1 from public.contract_occupancy_arrangements a
      where a.room_id=b.room_id and not a.released and a.id<>g.id) then
    if p_strict then raise exception 'Solo occupancy requires an empty destination room without another reservation'; end if;
    raise warning 'Solo transfer % requires an occupancy review; no arrangement was changed',t.id;
    return false;
  end if;
  v_previous := public.renewal_occupancy_snapshot(g.snapshot,c.tenant_id,c.starts_on,c.ends_on,c.monthly_rent);
  v_current := v_previous || jsonb_build_object('room_id',r.id,'room_number',r.room_number,'capacity',r.capacity,
    'members',(select jsonb_agg(m || jsonb_build_object('bed_id',b.id,'bed_label',b.label))
      from jsonb_array_elements(v_previous->'members') m));
  insert into public.solo_occupancy_relocations(occupancy_id,transfer_id,source_room_id,destination_room_id,previous_snapshot,current_snapshot)
    values(g.id,t.id,g.room_id,r.id,v_previous,v_current);
  update public.contract_occupancy_arrangements set room_id=r.id,snapshot=v_current where id=g.id;
  -- Refresh both room cards through the existing rooms realtime channel.
  update public.rooms set updated_at=clock_timestamp() where id in (g.room_id,r.id);
  return true;
end $$;
revoke all on function public.relocate_completed_solo_occupancy(uuid,boolean) from public,anon,authenticated;

create or replace function public.sync_solo_occupancy_after_transfer() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_transfer uuid;
begin
  if new.status<>'active' then return new; end if;
  select id into v_transfer from public.room_transfers where resulting_assignment_id=new.id and status='completed';
  if v_transfer is not null then perform public.relocate_completed_solo_occupancy(v_transfer,true); end if;
  return new;
end $$;
create trigger sync_solo_occupancy_after_transfer after insert on public.tenant_assignments
  for each row execute function public.sync_solo_occupancy_after_transfer();
revoke all on function public.sync_solo_occupancy_after_transfer() from public,anon,authenticated;

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
  v_snapshot := case when tg_op='UPDATE' and g.snapshot->>'mode'='solo'
    then new.occupancy_snapshot else g.snapshot end;
  if new.previous_contract_id is not null then
    select * into p from public.tenant_contracts where id=new.previous_contract_id;
    if p.occupancy_id is distinct from new.occupancy_id or p.tenant_id is distinct from new.tenant_id
      or p.occupancy_snapshot->>'mode' not in ('solo','standard_shared') then
      raise exception 'Renewal must retain an independently priced occupancy and tenant'; end if;
    if tg_op='UPDATE' and g.snapshot->>'mode'='solo' then
      -- Existing legal snapshots remain immutable after an approved room move.
      v_snapshot := new.occupancy_snapshot;
    else
      v_snapshot := public.renewal_occupancy_snapshot(
        case when g.snapshot->>'mode'='solo' then g.snapshot else p.occupancy_snapshot end,
        new.tenant_id,new.starts_on,new.ends_on,new.monthly_rent);
    end if;
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
    if exists(select 1 from jsonb_array_elements(case when g.snapshot->>'mode'='solo' then g.snapshot else v_snapshot end ->'members') x where
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
declare p public.tenant_contracts; c public.tenant_contracts; v_id uuid; v_snapshot jsonb; v_room uuid; v_live_snapshot jsonb;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Owner access required';
  end if;
  select * into p from public.tenant_contracts where id=p_previous_contract_id;
  if not found then raise exception 'Previous contract not found'; end if;
  if p.occupancy_id is not null then
    select room_id,snapshot into v_room,v_live_snapshot from public.contract_occupancy_arrangements where id=p.occupancy_id;
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
    v_snapshot := public.renewal_occupancy_snapshot(
      case when v_live_snapshot->>'mode'='solo' then v_live_snapshot else p.occupancy_snapshot end,
      p.tenant_id,p_starts_on,p_ends_on,p_monthly_rent);
  end if;
  insert into public.tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,security_deposit,status,notes,previous_contract_id,occupancy_id,occupancy_snapshot)
  values(p.tenant_id,p_starts_on,p_ends_on,p_monthly_rent,p.security_deposit,'draft',nullif(btrim(p_notes),''),p.id,p.occupancy_id,v_snapshot)
  returning id into v_id;
  return v_id;
end;
$$;

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
      'contract_id',c.id,'contract_number',c.contract_number,'status',case when g.is_history then 'transferred' else c.status end,
      'rent_cents',case when v_owner then case when g.is_history then m.value->'rent_cents' else to_jsonb(c.monthly_rent*100) end end
    )) order by m.value->>'tenant_id'),'[]'::jsonb)
    from jsonb_array_elements(g.snapshot->'members') m
    left join lateral (
      select c.* from public.tenant_contracts c where c.occupancy_id=g.contract_occupancy_id
        and c.tenant_id=(m.value->>'tenant_id')::uuid
        and (not g.is_history or c.id=g.history_contract_id)
      order by case c.status when 'active' then 0 when 'draft' then 1 when 'expired' then 2 else 3 end,
        c.starts_on desc,c.id limit 1
    ) c on true)
  )) order by g.created_at desc,g.id),'[]'::jsonb) into v_result
  from (
    select a.id,a.id as contract_occupancy_id,a.room_id,a.snapshot,a.released,a.created_at,false as is_history,
      null::uuid as history_contract_id
      from public.contract_occupancy_arrangements a
    union all
    select h.id,h.occupancy_id,h.source_room_id,h.previous_snapshot,true,h.applied_at,true,t.contract_id
      from public.solo_occupancy_relocations h join public.room_transfers t on t.id=h.transfer_id
      where coalesce(p_include_history,false)
  ) g
  left join lateral (
    select c.* from public.tenant_contracts c where c.occupancy_id=g.contract_occupancy_id
      and g.snapshot->>'mode'='solo' and not g.is_history
    order by case c.status when 'active' then 0 when 'draft' then 1 when 'expired' then 2 else 3 end,
      c.starts_on desc,c.id limit 1
  ) term on true
  where (p_room_id is null or g.room_id=p_room_id)
    and (coalesce(p_include_history,false) or not g.released);
  return v_result;
end $$;
-- Repair past completed transfers with a matching current assignment. Conflicting
-- destination arrangements are preserved for owner review rather than overwritten.
do $$
declare v_id uuid;
begin
  for v_id in select t.id from public.room_transfers t
    join public.tenant_assignments a on a.id=t.resulting_assignment_id and a.status='active'
    where t.status='completed' order by t.completed_at,t.id loop
    perform public.relocate_completed_solo_occupancy(v_id,false);
  end loop;
end $$;
notify pgrst,'reload schema';
commit;
