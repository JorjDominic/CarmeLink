-- Late returns require staff acknowledgment. Overnight leave requires a linked
-- guardian, or staff acknowledgment when no guardian is linked. Existing
-- approved/rejected states continue to control authorized absence windows.

create or replace function public.submit_curfew_request(
  p_destination text,
  p_reason text,
  p_departure_time timestamptz,
  p_expected_return_time timestamptz,
  p_request_type text default 'late_return'
) returns public.curfew_requests
language plpgsql security definer set search_path = '' as $$
declare v_row public.curfew_requests; v_status text;
begin
  if public.current_user_role() <> 'tenant' then raise exception 'Only tenants can submit curfew requests'; end if;
  if p_request_type not in ('late_return', 'overnight_leave') then raise exception 'Invalid curfew request type'; end if;
  if char_length(trim(coalesce(p_destination, ''))) < 2 then raise exception 'A destination is required'; end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then raise exception 'A reason is required'; end if;
  if p_expected_return_time <= p_departure_time then raise exception 'Expected return must be after departure'; end if;
  v_status := case when p_request_type = 'overnight_leave' and exists (
    select 1 from public.guardian_tenant_links where tenant_id = auth.uid()
  ) then 'pending_guardian' else 'pending_staff' end;
  insert into public.curfew_requests (
    tenant_id, destination, reason, departure_time,
    expected_return_time, request_type, status
  ) values (
    auth.uid(), trim(p_destination), trim(p_reason), p_departure_time,
    p_expected_return_time, p_request_type, v_status
  ) returning * into v_row;
  return v_row;
end $$;

revoke all on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text) from public, anon;
grant execute on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text) to authenticated;

create or replace function public.protect_curfew_request_update()
returns trigger language plpgsql set search_path = '' as $$
declare v_role public.app_role;
begin
  v_role := public.current_user_role();
  if new.tenant_id is distinct from old.tenant_id or
     new.request_type is distinct from old.request_type then
    raise exception 'Request ownership and type cannot be changed';
  end if;
  if v_role = 'tenant' then
    if old.tenant_id <> new.tenant_id or old.created_at <> new.created_at then
      raise exception 'Tenant cannot change curfew request ownership or creation time';
    end if;
    if new.status = 'cancelled' then
      if old.status not in ('pending_guardian', 'pending_staff') then raise exception 'Only pending curfew requests can be cancelled'; end if;
    elsif old.status not in ('pending_guardian', 'pending_staff') or new.status <> old.status then
      raise exception 'Tenant cannot change curfew approval status directly';
    end if;
    if new.guardian_decision is distinct from old.guardian_decision or
       new.guardian_decided_at is distinct from old.guardian_decided_at or
       new.staff_decision is distinct from old.staff_decision or
       new.staff_decided_at is distinct from old.staff_decided_at then
      raise exception 'Tenant cannot alter guardian or staff decisions';
    end if;
  elsif v_role = 'guardian' then
    if old.request_type <> 'overnight_leave' or old.status <> 'pending_guardian' then
      raise exception 'Guardians can only decide overnight requests awaiting guardian approval';
    end if;
    if not public.is_guardian_of(old.tenant_id) then raise exception 'Guardian is not linked to this tenant'; end if;
    if old.tenant_id <> new.tenant_id or old.destination <> new.destination or
       old.reason <> new.reason or old.departure_time <> new.departure_time or
       old.expected_return_time <> new.expected_return_time then
      raise exception 'Guardian cannot modify request details';
    end if;
    if new.guardian_decision is null or new.guardian_decision not in ('approved', 'rejected') then raise exception 'Guardian decision must be provided'; end if;
    if new.staff_id is distinct from old.staff_id or
       new.staff_decision is distinct from old.staff_decision or
       new.staff_notes is distinct from old.staff_notes or
       new.staff_decided_at is distinct from old.staff_decided_at then
      raise exception 'Guardian cannot alter staff fields';
    end if;
    new.guardian_id := auth.uid();
    new.guardian_decided_at := now();
    new.status := new.guardian_decision;
  elsif public.is_staff() then
    if new.guardian_id is distinct from old.guardian_id or
       new.guardian_decision is distinct from old.guardian_decision or
       new.guardian_remarks is distinct from old.guardian_remarks or
       new.guardian_decided_at is distinct from old.guardian_decided_at then
      raise exception 'Staff cannot alter guardian decisions';
    end if;
    if new.staff_decision is distinct from old.staff_decision or
       new.status is distinct from old.status then
      if old.status <> 'pending_staff' then
        raise exception 'Staff can only acknowledge requests awaiting staff review';
      end if;
      if old.request_type = 'overnight_leave' and exists (
        select 1 from public.guardian_tenant_links where tenant_id = old.tenant_id
      ) then
        raise exception 'Overnight leave with a linked guardian requires guardian acknowledgment';
      end if;
      if new.staff_decision is null or new.staff_decision not in ('approved', 'rejected') then
        raise exception 'Staff acknowledgment must accept or decline the request';
      end if;
      new.staff_id := auth.uid();
      new.staff_decided_at := now();
      new.status := new.staff_decision;
    end if;
  end if;
  return new;
end $$;

comment on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text) is
  'Routes late return to staff; overnight leave to a linked guardian, otherwise staff.';

-- Repair orphaned requests without attributing a guardian decision to staff.
update public.curfew_requests r
set status = 'pending_staff', updated_at = now()
where r.request_type = 'overnight_leave' and r.status = 'pending_guardian'
  and not exists (
    select 1 from public.guardian_tenant_links l where l.tenant_id = r.tenant_id
  );
