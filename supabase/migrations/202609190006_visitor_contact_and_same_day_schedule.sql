-- Require visitor contact details and enforce the dormitory's no-overnight rule.

alter table public.visitor_requests
  add column if not exists contact_number text,
  add column if not exists expected_departure_at timestamptz;

alter table public.visitor_requests
  add constraint visitor_requests_contact_number_check
  check (
    contact_number is null
    or contact_number ~ '^[0-9+() -]{7,20}$'
  ),
  add constraint visitor_requests_visit_window_check
  check (
    expected_departure_at is null
    or (
      expected_departure_at > schedule
      and (expected_departure_at at time zone 'Asia/Manila')::date
        = (schedule at time zone 'Asia/Manila')::date
    )
  );

create or replace function public.validate_visitor_request_details()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
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

  if (new.expected_departure_at at time zone 'Asia/Manila')::date
      <> (new.schedule at time zone 'Asia/Manila')::date then
    raise exception 'Overnight visitor stays are not permitted';
  end if;

  return new;
end;
$$;

drop trigger if exists visitor_requests_validate_details
  on public.visitor_requests;
create trigger visitor_requests_validate_details
before insert or update of
  visitor_name, relationship, purpose, contact_number, schedule,
  expected_departure_at
on public.visitor_requests
for each row
execute function public.validate_visitor_request_details();

create or replace function public.protect_tenant_visitor_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role text := public.current_user_role();
begin
  if old.tenant_id <> new.tenant_id then
    raise exception 'Visitor request ownership cannot be changed';
  end if;

  if old.created_at <> new.created_at then
    raise exception 'Visitor request creation time cannot be changed';
  end if;

  if v_role = 'tenant' then
    if old.status = 'pending' and new.status = 'cancelled' then
      if old.visitor_name <> new.visitor_name
        or old.relationship <> new.relationship
        or old.purpose <> new.purpose
        or old.contact_number is distinct from new.contact_number
        or old.schedule <> new.schedule
        or old.expected_departure_at is distinct from new.expected_departure_at then
        raise exception 'Cancellation cannot modify visitor request details';
      end if;
    elsif old.status = 'pending' and new.status = 'pending' then
      if new.decided_by is not null
        or new.decided_at is not null
        or new.arrived_at is not null
        or new.departed_at is not null then
        raise exception 'Tenant cannot set visitor review or presence fields';
      end if;
    else
      raise exception 'Tenant cannot perform this visitor request transition';
    end if;
  elsif public.is_staff() then
    if not (
      (old.status = 'pending' and new.status in ('approved', 'rejected'))
      or (old.status = 'approved' and new.status = 'arrived')
      or (old.status = 'arrived' and new.status = 'completed')
    ) then
      raise exception 'Invalid visitor request status transition';
    end if;
  else
    raise exception 'This role cannot update visitor requests';
  end if;

  return new;
end;
$$;

revoke all on function public.validate_visitor_request_details()
  from public, anon, authenticated;
