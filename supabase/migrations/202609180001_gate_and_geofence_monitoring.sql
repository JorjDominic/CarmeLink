-- Migration: 202609180001_gate_and_geofence_monitoring.sql
-- Implements the Gate & GPS Geofencing monitoring module under strict data-minimization rules.
-- Zero coordinates (lat/long) or raw distances are stored in this schema.
-- Only validated presence state (IN / OUT / UNAVAILABLE), verification method,
-- checkpoint type, and timestamps are persisted.

-- 1. Create public.gate_events table
create table if not exists public.gate_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  direction text check (direction in ('IN', 'OUT')),
  verification_method text not null check (verification_method in ('GPS Geofence', 'Staff Manual Log')),
  status text not null check (status in ('Verified', 'Flagged', 'UNAVAILABLE')),
  checkpoint_type text not null check (checkpoint_type in ('daytime', 'pre_curfew', 'curfew', 'manual_entry', 'on_demand')),
  checked_at timestamptz not null default now(),
  notes text null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),

  -- Rule 1: Direction must be NULL if UNAVAILABLE, and NOT NULL if Verified or Flagged
  constraint gate_event_direction_status_consistency check (
    (status = 'UNAVAILABLE' and direction is null) or
    (status in ('Verified', 'Flagged') and direction is not null)
  ),

  -- Rule 2: Notes are mandatory for Staff Manual Log entries
  constraint staff_manual_log_notes_required check (
    verification_method <> 'Staff Manual Log' or (notes is not null and length(trim(notes)) > 0)
  )
);

-- Indexes for performant filtering and timelines
create index if not exists gate_events_tenant_id_idx on public.gate_events (tenant_id);
create index if not exists gate_events_checked_at_idx on public.gate_events (checked_at desc);
create index if not exists gate_events_status_idx on public.gate_events (status);
create index if not exists gate_events_checkpoint_type_idx on public.gate_events (checkpoint_type);

-- 2. Add presence columns to public.tenant_details
-- DESIGN PRINCIPLE: tenant_details.current_gate_status reflects the tenant's last known physical direction 
-- (IN/OUT) or UNAVAILABLE if the last check failed. It does not track curfew compliance — whether the tenant's 
-- current absence is authorized is determined by checking whether her most recent gate_events row has status = 'Flagged', 
-- displayed separately as a warning indicator.
alter table public.tenant_details
  add column if not exists current_gate_status text not null default 'IN' check (current_gate_status in ('IN', 'OUT', 'UNAVAILABLE')),
  add column if not exists last_gate_event_at timestamptz default now();

-- 3. Trigger function to sync current presence into tenant_details
create or replace function public.sync_tenant_gate_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'UNAVAILABLE' then
    update public.tenant_details
      set current_gate_status = 'UNAVAILABLE',
          last_gate_event_at = new.checked_at,
          updated_at = now()
      where profile_id = new.tenant_id;
  elsif new.status in ('Verified', 'Flagged') then
    update public.tenant_details
      set current_gate_status = new.direction,
          last_gate_event_at = new.checked_at,
          updated_at = now()
      where profile_id = new.tenant_id;
  end if;

  if not found then
    insert into public.tenant_details (
      profile_id,
      current_gate_status,
      last_gate_event_at
    ) values (
      new.tenant_id,
      case when new.status = 'UNAVAILABLE' then 'UNAVAILABLE' else new.direction end,
      new.checked_at
    )
    on conflict (profile_id) do update
      set current_gate_status = excluded.current_gate_status,
          last_gate_event_at = excluded.last_gate_event_at,
          updated_at = now();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_tenant_gate_status on public.gate_events;
create trigger trg_sync_tenant_gate_status
after insert on public.gate_events
for each row execute function public.sync_tenant_gate_status();

-- 4. Secure RPC for Tenant GPS Geofence Check-in
create or replace function public.record_tenant_geofence_check(
  p_direction text,
  p_status text,
  p_checkpoint_type text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant_id uuid;
  v_effective_status text;
  v_event_id uuid;
  v_is_curfew_hours boolean;
  v_has_approved_exception boolean;
  v_current_hour int;
begin
  v_tenant_id := auth.uid();
  if v_tenant_id is null then
    raise exception 'Authentication required';
  end if;

  -- Ensure caller is a verified tenant
  if not exists (select 1 from public.profiles where id = v_tenant_id and role = 'tenant') then
    raise exception 'Only tenants can record GPS geofence checks';
  end if;

  if p_checkpoint_type not in ('daytime', 'pre_curfew', 'curfew', 'on_demand') then
    raise exception 'Invalid checkpoint type for tenant check-in';
  end if;

  if p_status not in ('Verified', 'UNAVAILABLE') then
    raise exception 'Invalid client status parameter';
  end if;

  v_effective_status := p_status;

  -- Curfew window evaluation (10:00 PM to 6:00 AM) in Philippine Standard Time (Asia/Manila)
  v_current_hour := extract(hour from (now() at time zone 'Asia/Manila'));
  v_is_curfew_hours := (v_current_hour >= 22 or v_current_hour < 6);

  if p_status = 'Verified' and p_direction = 'OUT' and v_is_curfew_hours then
    -- Check if tenant has an approved curfew exception or overnight leave covering now
    select exists (
      select 1 from public.curfew_requests
      where tenant_id = v_tenant_id
        and status = 'approved'
        and now() between departure_time and expected_return_time
    ) into v_has_approved_exception;

    if not v_has_approved_exception then
      v_effective_status := 'Flagged';
    end if;
  end if;

  -- Validate consistency before insert
  if v_effective_status = 'UNAVAILABLE' and p_direction is not null then
    raise exception 'Direction must be null when status is UNAVAILABLE';
  end if;

  if v_effective_status in ('Verified', 'Flagged') and p_direction is null then
    raise exception 'Direction is required when status is Verified or Flagged';
  end if;

  if p_direction is not null and p_direction not in ('IN', 'OUT') then
    raise exception 'Invalid direction: must be IN or OUT';
  end if;

  insert into public.gate_events (
    tenant_id,
    direction,
    verification_method,
    status,
    checkpoint_type,
    checked_at,
    created_by
  ) values (
    v_tenant_id,
    p_direction,
    'GPS Geofence',
    v_effective_status,
    p_checkpoint_type,
    now(),
    v_tenant_id
  ) returning id into v_event_id;

  return v_event_id;
end;
$$;

-- 5. Secure RPC for Staff Manual Log
create or replace function public.record_staff_manual_log(
  p_tenant_id uuid,
  p_direction text,
  p_notes text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_staff_id uuid;
  v_event_id uuid;
begin
  if not public.is_staff() then
    raise exception 'Staff authorization required';
  end if;

  v_staff_id := auth.uid();

  -- Verify target user is a tenant
  if not exists (select 1 from public.profiles where id = p_tenant_id and role = 'tenant') then
    raise exception 'Target user must be a registered tenant';
  end if;

  if p_direction not in ('IN', 'OUT') then
    raise exception 'Invalid direction: must be IN or OUT';
  end if;

  if p_notes is null or length(trim(p_notes)) = 0 then
    raise exception 'Mandatory observation notes required for staff manual log';
  end if;

  insert into public.gate_events (
    tenant_id,
    direction,
    verification_method,
    status,
    checkpoint_type,
    checked_at,
    notes,
    created_by
  ) values (
    p_tenant_id,
    p_direction,
    'Staff Manual Log',
    'Verified',
    'manual_entry',
    now(),
    trim(p_notes),
    v_staff_id
  ) returning id into v_event_id;

  return v_event_id;
end;
$$;

-- 6. Row Level Security & Permissions
alter table public.gate_events enable row level security;

-- Read policies
drop policy if exists "Staff full read access on gate_events" on public.gate_events;
create policy "Staff full read access on gate_events"
  on public.gate_events for select
  to authenticated
  using (public.is_staff());

drop policy if exists "Tenants can read own gate_events" on public.gate_events;
create policy "Tenants can read own gate_events"
  on public.gate_events for select
  to authenticated
  using (tenant_id = auth.uid());

drop policy if exists "Guardians can read linked tenant gate_events" on public.gate_events;
create policy "Guardians can read linked tenant gate_events"
  on public.gate_events for select
  to authenticated
  using (
    exists (
      select 1 from public.guardian_tenant_links
      where guardian_id = auth.uid()
        and tenant_id = public.gate_events.tenant_id
    )
  );

-- Revoke direct mutations from all client connections to preserve append-only integrity
revoke insert, update, delete on public.gate_events from public, anon, authenticated;
grant select on public.gate_events to authenticated;

-- Grant execute on security definer RPCs
revoke all on function public.record_tenant_geofence_check(text, text, text) from public, anon;
grant execute on function public.record_tenant_geofence_check(text, text, text) to authenticated;

revoke all on function public.record_staff_manual_log(uuid, text, text) from public, anon;
grant execute on function public.record_staff_manual_log(uuid, text, text) to authenticated;

-- 7. Register gate_events in realtime publication (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'gate_events'
  ) then
    alter publication supabase_realtime add table public.gate_events;
  end if;
end $$;
