-- Guardian-final overnight approval and durable guardian presence alerts.

create table if not exists public.guardian_alert_preferences (
  guardian_id uuid primary key references public.profiles(id) on delete cascade,
  gate_entry_enabled boolean not null default true,
  gate_exit_enabled boolean not null default true,
  outside_after_cutoff_enabled boolean not null default true,
  alert_cutoff time not null default time '21:00:00',
  timezone text not null default 'Asia/Manila'
    check (timezone = 'Asia/Manila'),
  updated_at timestamptz not null default now()
);

alter table public.guardian_alert_preferences enable row level security;
revoke all on public.guardian_alert_preferences from anon, authenticated;
grant select on public.guardian_alert_preferences to authenticated;

drop policy if exists "guardians read own alert preferences"
  on public.guardian_alert_preferences;
create policy "guardians read own alert preferences"
on public.guardian_alert_preferences for select to authenticated
using (guardian_id = (select auth.uid()) and public.current_user_role() = 'guardian');

create or replace function public.get_my_guardian_alert_preferences()
returns public.guardian_alert_preferences
language plpgsql security definer set search_path = '' as $$
declare v_row public.guardian_alert_preferences;
begin
  if public.current_user_role() <> 'guardian' then
    raise exception 'Guardian access required';
  end if;
  insert into public.guardian_alert_preferences (guardian_id)
  values (auth.uid()) on conflict (guardian_id) do nothing;
  select * into v_row from public.guardian_alert_preferences
  where guardian_id = auth.uid();
  return v_row;
end $$;

create or replace function public.update_my_guardian_alert_preferences(
  p_gate_entry_enabled boolean,
  p_gate_exit_enabled boolean,
  p_outside_after_cutoff_enabled boolean,
  p_alert_cutoff time
) returns public.guardian_alert_preferences
language plpgsql security definer set search_path = '' as $$
declare v_row public.guardian_alert_preferences;
begin
  if public.current_user_role() <> 'guardian' then
    raise exception 'Guardian access required';
  end if;
  if p_alert_cutoff is null then raise exception 'Alert cutoff is required'; end if;
  insert into public.guardian_alert_preferences (
    guardian_id, gate_entry_enabled, gate_exit_enabled,
    outside_after_cutoff_enabled, alert_cutoff, updated_at
  ) values (
    auth.uid(), coalesce(p_gate_entry_enabled, true),
    coalesce(p_gate_exit_enabled, true),
    coalesce(p_outside_after_cutoff_enabled, true), p_alert_cutoff, now()
  ) on conflict (guardian_id) do update set
    gate_entry_enabled = excluded.gate_entry_enabled,
    gate_exit_enabled = excluded.gate_exit_enabled,
    outside_after_cutoff_enabled = excluded.outside_after_cutoff_enabled,
    alert_cutoff = excluded.alert_cutoff,
    updated_at = now()
  returning * into v_row;
  return v_row;
end $$;

revoke all on function public.get_my_guardian_alert_preferences() from public, anon;
grant execute on function public.get_my_guardian_alert_preferences() to authenticated;
revoke all on function public.update_my_guardian_alert_preferences(boolean,boolean,boolean,time) from public, anon;
grant execute on function public.update_my_guardian_alert_preferences(boolean,boolean,boolean,time) to authenticated;

-- Existing overnight requests already endorsed by guardians no longer wait for staff.
update public.curfew_requests
set status = 'approved', updated_at = now()
where request_type = 'overnight_leave'
  and status = 'pending_staff'
  and guardian_decision = 'approved';

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
  if p_request_type = 'overnight_leave' and not exists (
    select 1 from public.guardian_tenant_links where tenant_id = auth.uid()
  ) then
    raise exception 'A linked guardian is required for an overnight leave request';
  end if;
  v_status := case when p_request_type = 'overnight_leave'
    then 'pending_guardian' else 'pending_staff' end;
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
    if new.guardian_decision not in ('approved', 'rejected') then raise exception 'Guardian decision must be provided'; end if;
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
    if old.request_type = 'overnight_leave' and
       (new.staff_decision is distinct from old.staff_decision or new.status is distinct from old.status) then
      raise exception 'Only the linked guardian may approve or reject overnight leave';
    end if;
    if old.request_type <> 'overnight_leave' and new.staff_decision is not null and
       new.staff_decision is distinct from old.staff_decision then
      new.staff_id := auth.uid(); new.staff_decided_at := now();
      new.status := new.staff_decision;
    end if;
  end if;
  return new;
end $$;

comment on table public.guardian_alert_preferences is
  'Durable guardian FCM preferences for entry, exit, and outside-after-cutoff alerts.';
comment on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text) is
  'Routes overnight leave exclusively to a linked guardian; late return remains a staff decision.';
