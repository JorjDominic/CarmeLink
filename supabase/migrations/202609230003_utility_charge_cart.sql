-- Utility cart supporting individual, selected-room, and all-room scopes.

create table public.utility_charge_batches (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete restrict default auth.uid(),
  item_count integer not null check (item_count > 0),
  total_amount numeric(12,2) not null check (total_amount > 0),
  created_at timestamptz not null default now()
);

create table public.utility_charge_batch_items (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.utility_charge_batches(id) on delete restrict,
  category text not null check (category in ('electricity','water','internet','utility')),
  title text not null,
  scope text not null check (scope in ('individual','selected_rooms','all_rooms')),
  allocation_method text not null check (allocation_method in ('equal_per_tenant','equal_per_room')),
  source_total numeric(12,2) not null check (source_total > 0),
  due_date date not null,
  period_start date not null,
  period_end date not null check (period_end >= period_start),
  target_tenant_id uuid references public.profiles(id) on delete restrict,
  target_room_numbers text[] not null default '{}',
  notes text,
  dedupe_key text not null unique,
  created_at timestamptz not null default now(),
  check (
    (scope = 'individual' and target_tenant_id is not null)
    or (scope = 'selected_rooms' and cardinality(target_room_numbers) > 0)
    or scope = 'all_rooms'
  )
);

create table public.utility_charge_allocations (
  id uuid primary key default gen_random_uuid(),
  batch_item_id uuid not null references public.utility_charge_batch_items(id) on delete restrict,
  charge_id uuid not null unique references public.billing_charges(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  room_number text not null,
  bed_label text not null,
  allocated_amount numeric(12,2) not null check (allocated_amount > 0),
  occupant_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  unique(batch_item_id, tenant_id)
);

alter table public.utility_charge_batches enable row level security;
alter table public.utility_charge_batch_items enable row level security;
alter table public.utility_charge_allocations enable row level security;

create policy utility_batches_staff_select on public.utility_charge_batches
for select to authenticated using ((select public.is_staff()));
create policy utility_batch_items_staff_select on public.utility_charge_batch_items
for select to authenticated using ((select public.is_staff()));
create policy utility_allocations_staff_select on public.utility_charge_allocations
for select to authenticated using ((select public.is_staff()));
create policy utility_allocations_tenant_select on public.utility_charge_allocations
for select to authenticated using (tenant_id = (select auth.uid()));

grant select on public.utility_charge_batches, public.utility_charge_batch_items,
  public.utility_charge_allocations to authenticated;
revoke insert, update, delete on public.utility_charge_batches,
  public.utility_charge_batch_items, public.utility_charge_allocations
  from authenticated;
revoke all on public.utility_charge_batches, public.utility_charge_batch_items,
  public.utility_charge_allocations from anon;

create or replace function public.create_utility_charge_cart(p_items jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_batch_id uuid;
  v_item jsonb;
  v_item_id uuid;
  v_item_count integer;
  v_total numeric(12,2);
  v_scope text;
  v_method text;
  v_category text;
  v_tenant_id uuid;
  v_rooms text[];
  v_occupant record;
  v_occupants integer;
  v_room_count integer;
  v_room_occupants integer;
  v_allocated numeric(12,2);
  v_running numeric(12,2);
  v_index integer;
  v_charge_id uuid;
  v_dedupe text;
  v_created integer := 0;
begin
  if not public.is_staff() then raise exception 'Owner or caretaker access required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Utility cart must contain at least one item';
  end if;
  v_item_count := jsonb_array_length(p_items);
  select sum((item->>'total_amount')::numeric) into v_total
  from jsonb_array_elements(p_items) item;
  if v_total is null or v_total <= 0 then raise exception 'Cart total must be positive'; end if;
  insert into public.utility_charge_batches(item_count,total_amount,created_by)
  values(v_item_count,v_total,auth.uid()) returning id into v_batch_id;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_scope := v_item->>'scope';
    v_method := coalesce(v_item->>'allocation_method','equal_per_tenant');
    v_category := lower(v_item->>'category');
    v_tenant_id := nullif(v_item->>'tenant_id','')::uuid;
    select coalesce(array_agg(value order by value),'{}') into v_rooms
      from jsonb_array_elements_text(coalesce(v_item->'room_numbers','[]')) value;
    if v_scope not in ('individual','selected_rooms','all_rooms') then raise exception 'Invalid utility scope'; end if;
    if v_method not in ('equal_per_tenant','equal_per_room') then raise exception 'Invalid allocation method'; end if;
    if v_category not in ('electricity','water','internet','utility') then raise exception 'Invalid utility category'; end if;
    if (v_item->>'total_amount')::numeric <= 0 then raise exception 'Utility total must be positive'; end if;
    if (v_item->>'period_end')::date < (v_item->>'period_start')::date then raise exception 'Invalid billing period'; end if;
    v_dedupe := md5(concat_ws('|',v_scope,v_category,v_item->>'period_start',
      coalesce(v_tenant_id::text,''),array_to_string(v_rooms,',')));

    insert into public.utility_charge_batch_items(
      batch_id,category,title,scope,allocation_method,source_total,due_date,
      period_start,period_end,target_tenant_id,target_room_numbers,notes,dedupe_key
    ) values (
      v_batch_id,v_category,trim(v_item->>'title'),v_scope,v_method,
      (v_item->>'total_amount')::numeric,(v_item->>'due_date')::date,
      (v_item->>'period_start')::date,(v_item->>'period_end')::date,
      v_tenant_id,v_rooms,nullif(trim(v_item->>'notes'),''),v_dedupe
    ) returning id into v_item_id;

    create temporary table if not exists utility_cart_occupants(
      tenant_id uuid, tenant_name text, room_number text, bed_label text
    ) on commit drop;
    truncate utility_cart_occupants;
    if v_scope = 'individual' then
      insert into utility_cart_occupants
      select p.id,p.full_name,coalesce(r.room_number,'Unassigned'),coalesce(b.label,'No bed')
      from public.profiles p
      left join public.tenant_assignments a on a.tenant_id=p.id and a.status='active'
      left join public.bed_spaces b on b.id=a.bed_space_id
      left join public.rooms r on r.id=b.room_id
      where p.id=v_tenant_id and p.role='tenant';
    else
      insert into utility_cart_occupants
      select p.id,p.full_name,r.room_number,b.label
      from public.tenant_assignments a
      join public.profiles p on p.id=a.tenant_id
      join public.bed_spaces b on b.id=a.bed_space_id
      join public.rooms r on r.id=b.room_id
      where a.status='active' and (v_scope='all_rooms' or r.room_number=any(v_rooms));
    end if;
    select count(*),count(distinct room_number) into v_occupants,v_room_count from utility_cart_occupants;
    if v_occupants=0 then raise exception 'Selected scope has no active occupants'; end if;
    v_running := 0; v_index := 0;
    for v_occupant in select * from utility_cart_occupants order by room_number,bed_label,tenant_id loop
      v_index := v_index + 1;
      if v_index = v_occupants then
        v_allocated := (v_item->>'total_amount')::numeric - v_running;
      elsif v_method='equal_per_room' then
        select count(*) into v_room_occupants from utility_cart_occupants where room_number=v_occupant.room_number;
        v_allocated := round(((v_item->>'total_amount')::numeric/v_room_count)/v_room_occupants,2);
      else
        v_allocated := round((v_item->>'total_amount')::numeric/v_occupants,2);
      end if;
      if v_allocated <= 0 then raise exception 'Allocation produced a non-positive tenant charge'; end if;
      v_running := v_running + v_allocated;
      insert into public.billing_charges(
        tenant_id,title,category,original_amount,due_date,period_start,period_end,
        source,terms_snapshot,notes,created_by
      ) values (
        v_occupant.tenant_id,trim(v_item->>'title'),v_category,v_allocated,
        (v_item->>'due_date')::date,(v_item->>'period_start')::date,
        (v_item->>'period_end')::date,'staff_entry',
        jsonb_build_object('batch_id',v_batch_id,'batch_item_id',v_item_id,
          'scope',v_scope,'allocation_method',v_method,'source_total',(v_item->>'total_amount')::numeric,
          'room_number',v_occupant.room_number,'bed_label',v_occupant.bed_label),
        nullif(trim(v_item->>'notes'),''),auth.uid()
      ) returning id into v_charge_id;
      insert into public.utility_charge_allocations(
        batch_item_id,charge_id,tenant_id,room_number,bed_label,allocated_amount,occupant_snapshot
      ) values (
        v_item_id,v_charge_id,v_occupant.tenant_id,v_occupant.room_number,
        v_occupant.bed_label,v_allocated,jsonb_build_object('tenant_id',v_occupant.tenant_id,
          'tenant_name',v_occupant.tenant_name,'room_number',v_occupant.room_number,
          'bed_label',v_occupant.bed_label)
      );
      v_created := v_created + 1;
    end loop;
  end loop;
  return jsonb_build_object('batch_id',v_batch_id,'item_count',v_item_count,
    'charge_count',v_created,'total_amount',v_total);
end; $$;

revoke all on function public.create_utility_charge_cart(jsonb) from public,anon;
grant execute on function public.create_utility_charge_cart(jsonb) to authenticated;
