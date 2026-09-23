-- Phase 2B: enforce the confirmed visitor scheduling policy at the database
-- boundary. This keeps the existing visitor workflow/RLS/RPC contract intact.
--
-- Confirmed rules enforced here:
--   * a tenant request/update must target at least the next Manila calendar day
--   * expected arrival is from 09:00 inclusive and before 21:00
--   * expected departure is after arrival, on the same Manila calendar day,
--     and no later than 21:00
--
-- Visitor ID image/OCR fields are intentionally NOT added here because the
-- required ID fields, exceptions, and retention period still need client
-- confirmation.

create or replace function public.validate_visitor_request_details()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_now_manila timestamp := now() at time zone 'Asia/Manila';
  v_schedule_manila timestamp;
  v_departure_manila timestamp;
begin
  -- Do not allow a client to spoof the creation timestamp to bypass the
  -- advance-registration rule.
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := now();
  end if;

  new.visitor_name := trim(new.visitor_name);
  new.relationship := trim(new.relationship);
  new.purpose := trim(new.purpose);
  new.contact_number := trim(coalesce(new.contact_number, ''));

  if char_length(new.contact_number) < 7 then
    raise exception 'A valid visitor contact number is required';
  end if;

  if new.expected_departure_at is null then
    raise exception 'Expected departure time is required';
  end if;

  if new.expected_departure_at <= new.schedule then
    raise exception 'Expected departure must be after arrival';
  end if;

  v_schedule_manila := new.schedule at time zone 'Asia/Manila';
  v_departure_manila :=
    new.expected_departure_at at time zone 'Asia/Manila';

  if v_schedule_manila::date <= v_now_manila::date then
    raise exception
      'Visitor requests must be submitted at least one calendar day before the visit';
  end if;

  if v_schedule_manila::time < time '09:00'
      or v_schedule_manila::time >= time '21:00' then
    raise exception
      'Expected arrival must be between 9:00 AM and before 9:00 PM';
  end if;

  if v_departure_manila::date <> v_schedule_manila::date then
    raise exception 'Overnight visitor stays are not permitted';
  end if;

  if v_departure_manila::time > time '21:00' then
    raise exception 'Expected departure must be no later than 9:00 PM';
  end if;

  return new;
end;
$$;

-- The trigger created by 202609190006 already calls the function above for
-- inserts and detail/schedule updates. Recreate it defensively so a database
-- built from the full migration chain has the intended column list.
drop trigger if exists visitor_requests_validate_details
  on public.visitor_requests;

create trigger visitor_requests_validate_details
before insert or update of
  visitor_name,
  relationship,
  purpose,
  contact_number,
  schedule,
  expected_departure_at
on public.visitor_requests
for each row
execute function public.validate_visitor_request_details();

-- Guard staff approval of legacy rows that may predate the stricter policy.
-- Approval uses creation date for the lead-time check so a request correctly
-- filed yesterday may still be approved on the visit date.
create or replace function public.enforce_visitor_approval_policy()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_created_manila timestamp;
  v_schedule_manila timestamp;
  v_departure_manila timestamp;
begin
  if old.status = 'pending' and new.status = 'approved' then
    if new.expected_departure_at is null then
      raise exception 'Expected departure time is required';
    end if;

    v_created_manila := new.created_at at time zone 'Asia/Manila';
    v_schedule_manila := new.schedule at time zone 'Asia/Manila';
    v_departure_manila :=
      new.expected_departure_at at time zone 'Asia/Manila';

    if v_schedule_manila::date <= v_created_manila::date then
      raise exception
        'Visitor requests must be submitted at least one calendar day before the visit';
    end if;

    if v_schedule_manila::time < time '09:00'
        or v_schedule_manila::time >= time '21:00' then
      raise exception
        'Expected arrival must be between 9:00 AM and before 9:00 PM';
    end if;

    if new.expected_departure_at <= new.schedule then
      raise exception 'Expected departure must be after arrival';
    end if;

    if v_departure_manila::date <> v_schedule_manila::date then
      raise exception 'Overnight visitor stays are not permitted';
    end if;

    if v_departure_manila::time > time '21:00' then
      raise exception 'Expected departure must be no later than 9:00 PM';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists visitor_requests_enforce_approval_policy
  on public.visitor_requests;

create trigger visitor_requests_enforce_approval_policy
before update of status
on public.visitor_requests
for each row
execute function public.enforce_visitor_approval_policy();

revoke all
on function public.validate_visitor_request_details()
from public, anon, authenticated;

revoke all
on function public.enforce_visitor_approval_policy()
from public, anon, authenticated;
