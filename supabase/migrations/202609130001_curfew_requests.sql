-- Migration: 202609130001_curfew_requests.sql
-- Implements the Curfew Exception Request module supporting two-tier approval
-- (Tenant submission -> Guardian decision -> Staff final decision).

create table public.curfew_requests (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null
    references public.profiles(id)
    on delete cascade,

  destination text not null
    check (
      char_length(trim(destination)) between 2 and 150
    ),

  reason text not null
    check (
      char_length(trim(reason)) between 2 and 300
    ),

  departure_time timestamptz not null,
  expected_return_time timestamptz not null,

  status text not null default 'pending_guardian'
    check (
      status in (
        'pending_guardian',
        'pending_staff',
        'approved',
        'rejected',
        'cancelled',
        'completed'
      )
    ),

  -- Guardian review fields
  guardian_id uuid
    references public.profiles(id)
    on delete set null,
  guardian_decision text
    check (
      guardian_decision is null
      or guardian_decision in ('approved', 'rejected')
    ),
  guardian_remarks text,
  guardian_decided_at timestamptz,

  -- Staff review fields
  staff_id uuid
    references public.profiles(id)
    on delete set null,
  staff_decision text
    check (
      staff_decision is null
      or staff_decision in ('approved', 'rejected')
    ),
  staff_notes text,
  staff_decided_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (expected_return_time > departure_time)
);

create index curfew_requests_tenant_id_idx
  on public.curfew_requests (tenant_id);

create index curfew_requests_status_idx
  on public.curfew_requests (status);

create index curfew_requests_departure_time_idx
  on public.curfew_requests (departure_time);

create trigger curfew_requests_set_updated_at
  before update on public.curfew_requests
  for each row
  execute function public.set_updated_at();

-- Trigger to protect unauthorized field mutations by role
create or replace function public.protect_curfew_request_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role public.app_role;
begin
  v_role := public.current_user_role();

  if v_role = 'tenant' then
    if old.tenant_id <> new.tenant_id then
      raise exception 'Tenant cannot change curfew request ownership';
    end if;

    if old.created_at <> new.created_at then
      raise exception 'Tenant cannot change curfew request creation time';
    end if;

    -- Tenant can only cancel, or edit details while still pending_guardian
    if new.status = 'cancelled' then
      if old.status not in ('pending_guardian', 'pending_staff') then
        raise exception 'Only pending curfew requests can be cancelled';
      end if;
    elsif old.status <> 'pending_guardian' then
      raise exception 'Only pending_guardian curfew requests can be modified';
    elsif new.status <> old.status then
      raise exception 'Tenant cannot change curfew approval status directly';
    end if;

    -- Prevent tenant tampering with decisions
    if new.guardian_decision is distinct from old.guardian_decision or
       new.guardian_decided_at is distinct from old.guardian_decided_at or
       new.staff_decision is distinct from old.staff_decision or
       new.staff_decided_at is distinct from old.staff_decided_at then
      raise exception 'Tenant cannot alter guardian or staff decisions';
    end if;

  elsif v_role = 'guardian' then
    if old.tenant_id <> new.tenant_id or
       old.destination <> new.destination or
       old.reason <> new.reason or
       old.departure_time <> new.departure_time or
       old.expected_return_time <> new.expected_return_time then
      raise exception 'Guardian cannot modify request departure details';
    end if;

    if old.status <> 'pending_guardian' then
      raise exception 'Guardian can only decide requests awaiting guardian review';
    end if;

    if new.guardian_decision is null then
      raise exception 'Guardian decision must be provided';
    end if;

    new.guardian_id := auth.uid();
    new.guardian_decided_at := now();

    if new.guardian_decision = 'approved' then
      new.status := 'pending_staff';
    else
      new.status := 'rejected';
    end if;

  elsif public.is_staff() then
    -- Staff decision
    if new.staff_decision is not null and new.staff_decision is distinct from old.staff_decision then
      new.staff_id := auth.uid();
      new.staff_decided_at := now();

      if new.staff_decision = 'approved' then
        new.status := 'approved';
      else
        new.status := 'rejected';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger curfew_requests_protect_update
  before update on public.curfew_requests
  for each row
  execute function public.protect_curfew_request_update();

-- Row Level Security
alter table public.curfew_requests enable row level security;

-- Tenant policies
create policy "tenants read own curfew requests"
  on public.curfew_requests
  for select
  to authenticated
  using (
    tenant_id = (select auth.uid())
  );

create policy "tenants create own curfew requests"
  on public.curfew_requests
  for insert
  to authenticated
  with check (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
    and status = 'pending_guardian'
  );

create policy "tenants update own pending curfew requests"
  on public.curfew_requests
  for update
  to authenticated
  using (
    tenant_id = (select auth.uid())
    and status in ('pending_guardian', 'pending_staff')
    and (select public.current_user_role()) = 'tenant'
  )
  with check (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
  );

create policy "tenants delete own pending curfew requests"
  on public.curfew_requests
  for delete
  to authenticated
  using (
    tenant_id = (select auth.uid())
    and status = 'pending_guardian'
    and (select public.current_user_role()) = 'tenant'
  );

-- Guardian policies
create policy "guardians read linked tenant curfew requests"
  on public.curfew_requests
  for select
  to authenticated
  using (
    (select public.current_user_role()) = 'guardian'
    and public.is_guardian_of(tenant_id)
  );

create policy "guardians update linked tenant curfew requests"
  on public.curfew_requests
  for update
  to authenticated
  using (
    (select public.current_user_role()) = 'guardian'
    and public.is_guardian_of(tenant_id)
    and status = 'pending_guardian'
  )
  with check (
    (select public.current_user_role()) = 'guardian'
    and public.is_guardian_of(tenant_id)
  );

-- Staff policies
create policy "staff read curfew requests"
  on public.curfew_requests
  for select
  to authenticated
  using (
    (select public.is_staff())
  );

create policy "staff update curfew requests"
  on public.curfew_requests
  for update
  to authenticated
  using (
    (select public.is_staff())
  )
  with check (
    (select public.is_staff())
  );

-- Permissions
revoke all on table public.curfew_requests from anon;
revoke all on table public.curfew_requests from authenticated;

grant select, insert, update, delete
  on table public.curfew_requests
  to authenticated;

revoke all on function public.protect_curfew_request_update() from public, anon, authenticated;

-- Realtime Publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'curfew_requests'
  ) then
    alter publication supabase_realtime add table public.curfew_requests;
  end if;
end;
$$;

