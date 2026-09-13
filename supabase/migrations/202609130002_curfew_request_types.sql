-- Migration: 202609130002_curfew_request_types.sql
-- Adds request_type column to curfew_requests supporting differentiated routing:
-- 1. 'late_return': Same-night late return (direct to staff/caretaker, initial status 'pending_staff')
-- 2. 'overnight_leave': Sleeping outside dormitory premises (guardian endorsement first, initial status 'pending_guardian')

alter table public.curfew_requests
  add column if not exists request_type text not null default 'late_return'
    check (request_type in ('late_return', 'overnight_leave'));

-- Index on request_type
create index if not exists curfew_requests_request_type_idx
  on public.curfew_requests (request_type);

-- Update trigger function to support late_return (starting at pending_staff)
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

    -- Tenant cannot change request_type on update
    if new.request_type <> old.request_type then
      raise exception 'Tenant cannot change request type after submission';
    end if;

    -- Tenant can cancel anytime while pending, or edit details while still pending
    if new.status = 'cancelled' then
      if old.status not in ('pending_guardian', 'pending_staff') then
        raise exception 'Only pending curfew requests can be cancelled';
      end if;
    elsif old.status not in ('pending_guardian', 'pending_staff') then
      raise exception 'Only pending curfew requests can be modified';
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

-- Drop and recreate tenant insert policy to allow both pending_guardian (overnight_leave) and pending_staff (late_return)
drop policy if exists "tenants create own curfew requests" on public.curfew_requests;

create policy "tenants create own curfew requests"
  on public.curfew_requests
  for insert
  to authenticated
  with check (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
    and (
      (request_type = 'late_return' and status = 'pending_staff')
      or
      (request_type = 'overnight_leave' and status = 'pending_guardian')
    )
  );

-- Also ensure tenant can delete or update pending requests if needed
drop policy if exists "tenants delete own pending curfew requests" on public.curfew_requests;

create policy "tenants delete own pending curfew requests"
  on public.curfew_requests
  for delete
  to authenticated
  using (
    tenant_id = (select auth.uid())
    and status in ('pending_guardian', 'pending_staff')
    and (select public.current_user_role()) = 'tenant'
  );

