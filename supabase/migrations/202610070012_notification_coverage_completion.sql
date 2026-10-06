begin;

-- Complete notification coverage for secondary workflows that previously only
-- refreshed their data views. Every row below is persisted first and enters the
-- existing retryable push queue through the generic server_push trigger.

create or replace function public.emit_app_notification(
  p_recipient_id uuid,
  p_notification_type text,
  p_title text,
  p_body text,
  p_route_type text,
  p_route_id uuid,
  p_data jsonb,
  p_event_key text,
  p_dedupe_seconds integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_recipient_id is null then return; end if;
  if auth.uid() is not null and p_recipient_id = auth.uid() then return; end if;

  if p_event_key is not null and exists (
    select 1
    from public.app_notifications n
    where n.recipient_id = p_recipient_id
      and n.data ->> 'event_key' = p_event_key
      and (
        p_dedupe_seconds = 0
        or n.created_at >= now() - (greatest(p_dedupe_seconds, 1) * interval '1 second')
      )
  ) then
    return;
  end if;

  insert into public.app_notifications (
    recipient_id,
    notification_type,
    title,
    body,
    route_type,
    route_id,
    data
  ) values (
    p_recipient_id,
    p_notification_type,
    left(btrim(p_title), 120),
    left(btrim(p_body), 500),
    p_route_type,
    p_route_id,
    coalesce(p_data, '{}'::jsonb)
      || jsonb_build_object(
        'server_push', true,
        'event_key', p_event_key
      )
  );
end;
$$;

create or replace function public.emit_staff_notification(
  p_notification_type text,
  p_title text,
  p_body text,
  p_route_type text,
  p_route_id uuid,
  p_data jsonb,
  p_event_key text,
  p_dedupe_seconds integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient uuid;
begin
  for v_recipient in
    select p.id
    from public.profiles p
    where p.role::text in ('owner', 'caretaker')
  loop
    perform public.emit_app_notification(
      v_recipient,
      p_notification_type,
      p_title,
      p_body,
      p_route_type,
      p_route_id,
      p_data,
      p_event_key,
      p_dedupe_seconds
    );
  end loop;
end;
$$;

create or replace function public.emit_tenant_circle_notification(
  p_tenant_id uuid,
  p_include_tenant boolean,
  p_include_guardians boolean,
  p_notification_type text,
  p_title text,
  p_body text,
  p_route_type text,
  p_route_id uuid,
  p_data jsonb,
  p_event_key text,
  p_dedupe_seconds integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guardian uuid;
  v_data jsonb := coalesce(p_data, '{}'::jsonb)
    || jsonb_build_object('tenant_id', p_tenant_id);
begin
  if p_include_tenant then
    perform public.emit_app_notification(
      p_tenant_id,
      p_notification_type,
      p_title,
      p_body,
      p_route_type,
      p_route_id,
      v_data,
      p_event_key,
      p_dedupe_seconds
    );
  end if;

  if p_include_guardians then
    for v_guardian in
      select link.guardian_id
      from public.guardian_tenant_links link
      where link.tenant_id = p_tenant_id
    loop
      perform public.emit_app_notification(
        v_guardian,
        p_notification_type,
        p_title,
        p_body,
        p_route_type,
        p_route_id,
        v_data,
        p_event_key,
        p_dedupe_seconds
      );
    end loop;
  end if;
end;
$$;

-- Contract/onboarding milestones ------------------------------------------------
create or replace function public.notify_contract_requirement_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_contract_number text;
  v_label text := initcap(replace(new.requirement_type, '_', ' '));
begin
  if new.status is not distinct from old.status then return new; end if;

  select c.tenant_id, c.contract_number
  into v_tenant, v_contract_number
  from public.tenant_contracts c
  where c.id = new.contract_id;

  if new.status = 'pending_review' then
    perform public.emit_staff_notification(
      'onboarding',
      'Contract document ready for review',
      v_label || ' was submitted for ' || coalesce(v_contract_number, 'a draft contract') || '.',
      'onboarding',
      new.contract_id,
      jsonb_build_object(
        'contract_id', new.contract_id,
        'requirement_id', new.id,
        'requirement_type', new.requirement_type,
        'status', new.status
      ),
      'contract_requirement:' || new.id::text || ':' || new.status,
      0
    );
  elsif new.status in ('verified', 'rejected', 'waived') then
    perform public.emit_tenant_circle_notification(
      v_tenant,
      true,
      new.requirement_type = 'guardian_identity',
      'onboarding',
      'Contract requirement updated',
      v_label || ' is now ' || replace(new.status, '_', ' ') || '.',
      'onboarding',
      new.contract_id,
      jsonb_build_object(
        'contract_id', new.contract_id,
        'requirement_id', new.id,
        'requirement_type', new.requirement_type,
        'status', new.status
      ),
      'contract_requirement:' || new.id::text || ':' || new.status,
      0
    );
  end if;

  return new;
end;
$$;

drop trigger if exists contract_requirement_notification on public.contract_requirements;
create trigger contract_requirement_notification
after update of status on public.contract_requirements
for each row execute function public.notify_contract_requirement_event();

create or replace function public.notify_contract_signer_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_contract_number text;
  v_label text := initcap(replace(new.signer_role, '_', ' '));
begin
  if new.status is not distinct from old.status then return new; end if;

  select c.tenant_id, c.contract_number
  into v_tenant, v_contract_number
  from public.tenant_contracts c
  where c.id = new.contract_id;

  if new.status = 'signed' then
    perform public.emit_staff_notification(
      'onboarding',
      'Contract signature submitted',
      v_label || ' signature was submitted for ' || coalesce(v_contract_number, 'a draft contract') || '.',
      'onboarding',
      new.contract_id,
      jsonb_build_object(
        'contract_id', new.contract_id,
        'signer_id', new.id,
        'signer_role', new.signer_role,
        'status', new.status
      ),
      'contract_signer:' || new.id::text || ':' || new.status,
      0
    );
  elsif new.status in ('verified', 'rejected', 'waived') then
    perform public.emit_tenant_circle_notification(
      v_tenant,
      true,
      new.signer_role = 'guardian',
      'onboarding',
      'Contract signature updated',
      v_label || ' signature is now ' || replace(new.status, '_', ' ') || '.',
      'onboarding',
      new.contract_id,
      jsonb_build_object(
        'contract_id', new.contract_id,
        'signer_id', new.id,
        'signer_role', new.signer_role,
        'status', new.status
      ),
      'contract_signer:' || new.id::text || ':' || new.status,
      0
    );
  end if;

  return new;
end;
$$;

drop trigger if exists contract_signer_notification on public.contract_signers;
create trigger contract_signer_notification
after update of status on public.contract_signers
for each row execute function public.notify_contract_signer_event();

create or replace function public.notify_contract_status_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_body text;
  v_status text := replace(new.status::text, '_', ' ');
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;

  v_title := case when tg_op = 'INSERT'
    then 'Dormitory contract created'
    else 'Dormitory contract updated'
  end;
  v_body := coalesce(new.contract_number, 'Your contract') || ' is ' || v_status || '.';

  perform public.emit_tenant_circle_notification(
    new.tenant_id,
    true,
    true,
    'onboarding',
    v_title,
    v_body,
    'onboarding',
    new.id,
    jsonb_build_object(
      'contract_id', new.id,
      'status', new.status::text
    ),
    'contract_status:' || new.id::text || ':' || new.status::text,
    0
  );

  return new;
end;
$$;

drop trigger if exists tenant_contract_status_notification on public.tenant_contracts;
create trigger tenant_contract_status_notification
after insert or update of status on public.tenant_contracts
for each row execute function public.notify_contract_status_event();

-- Move-out / settlement ---------------------------------------------------------
create or replace function public.notify_move_out_case_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_body text;
  v_status text := replace(new.status, '_', ' ');
  v_key text;
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then return new; end if;

  v_title := case when tg_op = 'INSERT'
    then 'Move-out notice recorded'
    else 'Move-out status updated'
  end;
  v_body := new.tenant_name_snapshot || ': ' || v_status || '.';
  v_key := 'move_out:' || new.id::text || ':' || new.status;

  perform public.emit_staff_notification(
    'system',
    v_title,
    v_body,
    'move_out',
    new.id,
    jsonb_build_object(
      'case_id', new.id,
      'tenant_id', new.tenant_id,
      'status', new.status
    ),
    v_key,
    0
  );

  perform public.emit_tenant_circle_notification(
    new.tenant_id,
    true,
    true,
    'system',
    v_title,
    'Your move-out record is now ' || v_status || '.',
    'move_out',
    new.id,
    jsonb_build_object(
      'case_id', new.id,
      'status', new.status
    ),
    v_key,
    0
  );

  return new;
end;
$$;

drop trigger if exists move_out_case_notification on public.move_out_cases;
create trigger move_out_case_notification
after insert or update of status on public.move_out_cases
for each row execute function public.notify_move_out_case_event();

create or replace function public.notify_move_out_settlement_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_status text := replace(new.refund_status, '_', ' ');
begin
  if new.refund_status is not distinct from old.refund_status then return new; end if;

  select c.tenant_id into v_tenant
  from public.move_out_cases c
  where c.id = new.case_id;

  perform public.emit_tenant_circle_notification(
    v_tenant,
    true,
    true,
    'payment',
    'Move-out settlement updated',
    'Settlement status is now ' || v_status || '.',
    'move_out',
    new.case_id,
    jsonb_build_object(
      'case_id', new.case_id,
      'refund_status', new.refund_status,
      'refundable_amount', new.refundable_amount,
      'shortfall_amount', new.shortfall_amount
    ),
    'move_out_settlement:' || new.case_id::text || ':' || new.refund_status,
    0
  );

  return new;
end;
$$;

drop trigger if exists move_out_settlement_notification on public.move_out_settlements;
create trigger move_out_settlement_notification
after update of refund_status on public.move_out_settlements
for each row execute function public.notify_move_out_settlement_event();

-- Room assignment ---------------------------------------------------------------
create or replace function public.notify_room_assignment_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
  v_room text;
  v_bed text;
begin
  if new.status::text <> 'active' then return new; end if;
  if tg_op = 'UPDATE'
     and old.status::text = 'active'
     and new.bed_space_id is not distinct from old.bed_space_id then
    return new;
  end if;

  select r.id, r.room_number, b.label
  into v_room_id, v_room, v_bed
  from public.bed_spaces b
  join public.rooms r on r.id = b.room_id
  where b.id = new.bed_space_id;

  perform public.emit_tenant_circle_notification(
    new.tenant_id,
    true,
    true,
    'system',
    'Room assignment updated',
    'Assigned to Room ' || coalesce(v_room, '—') || ' • ' || coalesce(v_bed, 'Bed') || '.',
    'room_assignment',
    v_room_id,
    jsonb_build_object(
      'assignment_id', new.id,
      'room_id', v_room_id,
      'room_number', v_room,
      'bed_label', v_bed
    ),
    'room_assignment:' || new.id::text,
    0
  );

  return new;
end;
$$;

drop trigger if exists tenant_assignment_notification on public.tenant_assignments;
create trigger tenant_assignment_notification
after insert or update of bed_space_id, status on public.tenant_assignments
for each row execute function public.notify_room_assignment_event();

-- Cleaning rotation -------------------------------------------------------------
create or replace function public.notify_cleaning_schedule_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_room text;
  v_bed text;
begin
  if not new.is_active then return new; end if;

  select a.tenant_id, r.room_number, b.label
  into v_tenant, v_room, v_bed
  from public.tenant_assignments a
  join public.bed_spaces b on b.id = a.bed_space_id
  join public.rooms r on r.id = b.room_id
  where a.bed_space_id = new.bed_space_id
    and a.status::text = 'active'
  order by a.created_at desc
  limit 1;

  if v_tenant is null then return new; end if;

  perform public.emit_app_notification(
    v_tenant,
    'maintenance',
    'Cleaning rotation updated',
    'Your cleaning duty for Room ' || coalesce(v_room, '—') || ' • ' || coalesce(v_bed, 'Bed') || ' was updated. Open the schedule for current duties.',
    'cleaning_schedule',
    new.bed_space_id,
    jsonb_build_object(
      'schedule_id', new.id,
      'bed_space_id', new.bed_space_id,
      'weekday', new.weekday,
      'generation_source', new.generation_source
    ),
    'cleaning_schedule:' || new.bed_space_id::text,
    60
  );

  return new;
end;
$$;

drop trigger if exists cleaning_schedule_notification on public.cleaning_schedules;
create trigger cleaning_schedule_notification
after insert or update of weekday, task_notes, is_active, generation_source
on public.cleaning_schedules
for each row execute function public.notify_cleaning_schedule_event();

-- Employee-curfew profiles ------------------------------------------------------
create or replace function public.notify_employee_curfew_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_body text;
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status not in ('approved', 'revoked') then return new; end if;

  v_title := case when new.status = 'approved'
    then 'Work curfew schedule approved'
    else 'Work curfew schedule revoked'
  end;
  v_body := case when new.status = 'approved'
    then 'Your employment-based curfew schedule is now approved.'
    else 'Your employment-based curfew schedule was revoked. Open your curfew page for details.'
  end;

  perform public.emit_app_notification(
    new.tenant_id,
    'curfew',
    v_title,
    v_body,
    'employee_curfew',
    new.id,
    jsonb_build_object(
      'profile_id', new.id,
      'status', new.status
    ),
    'employee_curfew:' || new.id::text || ':' || new.status,
    0
  );

  return new;
end;
$$;

drop trigger if exists employee_curfew_notification on public.employee_curfew_profiles;
create trigger employee_curfew_notification
after update of status on public.employee_curfew_profiles
for each row execute function public.notify_employee_curfew_event();

-- Guardian linking --------------------------------------------------------------
create or replace function public.notify_guardian_link_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guardian uuid := case when tg_op = 'DELETE' then old.guardian_id else new.guardian_id end;
  v_tenant uuid := case when tg_op = 'DELETE' then old.tenant_id else new.tenant_id end;
  v_added boolean := tg_op = 'INSERT';
  v_title text := case when tg_op = 'INSERT' then 'Guardian link added' else 'Guardian link removed' end;
  v_body text := case when tg_op = 'INSERT'
    then 'A verified guardian/resident link was added to your account.'
    else 'A guardian/resident link was removed from your account.'
  end;
  v_key text := 'guardian_link:' || coalesce(v_guardian::text, '') || ':' || coalesce(v_tenant::text, '') || ':' || case when tg_op = 'INSERT' then 'added' else 'removed' end;
begin
  perform public.emit_app_notification(
    v_guardian,
    'system',
    v_title,
    v_body,
    'guardian_link',
    v_tenant,
    jsonb_build_object('tenant_id', v_tenant, 'linked', v_added),
    v_key,
    0
  );
  perform public.emit_app_notification(
    v_tenant,
    'system',
    v_title,
    v_body,
    'guardian_link',
    v_guardian,
    jsonb_build_object('guardian_id', v_guardian, 'linked', v_added),
    v_key,
    0
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists guardian_link_notification on public.guardian_tenant_links;
create trigger guardian_link_notification
after insert or delete on public.guardian_tenant_links
for each row execute function public.notify_guardian_link_event();

-- Inspection scheduling ---------------------------------------------------------
create or replace function public.notify_room_inspection_schedule_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant uuid;
  v_room text;
  v_key text;
begin
  if new.status <> 'scheduled'
     or new.scheduled_at is null
     or new.notice_published_at is null then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and new.status is not distinct from old.status
     and new.scheduled_at is not distinct from old.scheduled_at
     and new.notice_published_at is not distinct from old.notice_published_at then
    return new;
  end if;

  select r.room_number into v_room from public.rooms r where r.id = new.room_id;
  v_key := 'inspection_scheduled:' || new.id::text || ':' || new.scheduled_at::text;

  for v_tenant in
    select a.tenant_id
    from public.tenant_assignments a
    join public.bed_spaces b on b.id = a.bed_space_id
    where b.room_id = new.room_id and a.status::text = 'active'
  loop
    perform public.emit_app_notification(
      v_tenant,
      'maintenance',
      'Room inspection scheduled',
      'An inspection for Room ' || coalesce(v_room, '—') || ' is scheduled for ' || to_char(new.scheduled_at at time zone 'Asia/Manila', 'Mon DD, YYYY HH12:MI AM') || '.',
      'inspection',
      new.id,
      jsonb_build_object(
        'inspection_id', new.id,
        'room_id', new.room_id,
        'scheduled_at', new.scheduled_at
      ),
      v_key,
      0
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists room_inspection_schedule_notification on public.room_inspections;
create trigger room_inspection_schedule_notification
after insert or update of status, scheduled_at, notice_published_at on public.room_inspections
for each row execute function public.notify_room_inspection_schedule_event();

-- Contract-expiry reminders -----------------------------------------------------
create or replace function public.process_contract_expiry_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract record;
  v_days integer;
  v_today date := (now() at time zone 'Asia/Manila')::date;
  v_count integer := 0;
  v_key text;
begin
  for v_contract in
    select c.id, c.tenant_id, c.contract_number, c.ends_on
    from public.tenant_contracts c
    where c.status::text = 'active'
      and c.ends_on between v_today and v_today + 30
  loop
    v_days := v_contract.ends_on - v_today;
    if v_days not in (30, 7, 1, 0) then continue; end if;
    v_key := 'contract_expiry:' || v_contract.id::text || ':' || v_days::text;

    perform public.emit_staff_notification(
      'onboarding',
      case when v_days = 0 then 'Contract expires today' else 'Contract expiring soon' end,
      coalesce(v_contract.contract_number, 'A tenant contract') ||
        case when v_days = 0 then ' expires today.' else ' expires in ' || v_days::text || ' day(s).' end,
      'onboarding',
      v_contract.id,
      jsonb_build_object('contract_id', v_contract.id, 'days_remaining', v_days),
      v_key,
      0
    );

    perform public.emit_tenant_circle_notification(
      v_contract.tenant_id,
      true,
      true,
      'onboarding',
      case when v_days = 0 then 'Your contract expires today' else 'Your contract is expiring soon' end,
      case when v_days = 0
        then 'Review renewal or move-out arrangements with dormitory staff.'
        else 'Your dormitory contract expires in ' || v_days::text || ' day(s). Review renewal or move-out arrangements.'
      end,
      'onboarding',
      v_contract.id,
      jsonb_build_object('contract_id', v_contract.id, 'days_remaining', v_days),
      v_key,
      0
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create extension if not exists pg_cron with schema extensions;
do $$
declare
  v_job bigint;
begin
  for v_job in select jobid from cron.job where jobname = 'contract-expiry-notifications' loop
    perform cron.unschedule(v_job);
  end loop;
  perform cron.schedule(
    'contract-expiry-notifications',
    '15 0 * * *',
    'select public.process_contract_expiry_notifications();'
  );
end $$;

revoke all on function public.emit_app_notification(uuid,text,text,text,text,uuid,jsonb,text,integer)
  from public, anon, authenticated;
revoke all on function public.emit_staff_notification(text,text,text,text,uuid,jsonb,text,integer)
  from public, anon, authenticated;
revoke all on function public.emit_tenant_circle_notification(uuid,boolean,boolean,text,text,text,text,uuid,jsonb,text,integer)
  from public, anon, authenticated;
revoke all on function public.notify_contract_requirement_event()
  from public, anon, authenticated;
revoke all on function public.notify_contract_signer_event()
  from public, anon, authenticated;
revoke all on function public.notify_contract_status_event()
  from public, anon, authenticated;
revoke all on function public.notify_move_out_case_event()
  from public, anon, authenticated;
revoke all on function public.notify_move_out_settlement_event()
  from public, anon, authenticated;
revoke all on function public.notify_room_assignment_event()
  from public, anon, authenticated;
revoke all on function public.notify_cleaning_schedule_event()
  from public, anon, authenticated;
revoke all on function public.notify_employee_curfew_event()
  from public, anon, authenticated;
revoke all on function public.notify_guardian_link_event()
  from public, anon, authenticated;
revoke all on function public.notify_room_inspection_schedule_event()
  from public, anon, authenticated;
revoke all on function public.process_contract_expiry_notifications()
  from public, anon, authenticated;

commit;
