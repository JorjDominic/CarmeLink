begin;

-- Phase 3 carry-over: owner-configured report choices should reach already-open
-- tenant forms through the same realtime refresh layer used elsewhere.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'dormitory_options'
  ) then
    alter publication supabase_realtime add table public.dormitory_options;
  end if;
end $$;

-- Visitor rescheduling is append-only in visitor history. The request keeps its
-- current row for operational use, while this event records who changed the
-- schedule and the previous/new times.
alter table public.visitor_events
  drop constraint if exists visitor_events_event_type_check;

alter table public.visitor_events
  add constraint visitor_events_event_type_check
  check (event_type in (
    'approved',
    'rejected',
    'cancelled',
    'arrived',
    'departed',
    'rescheduled'
  ));

alter table public.visitor_events
  add column if not exists details jsonb not null default '{}'::jsonb;

-- Keep direct visitor updates constrained. The schedule RPC below sets a
-- transaction-local marker after it has locked, authorized and validated the
-- request; the trigger only relaxes transition checks for that controlled path.
create or replace function public.protect_tenant_visitor_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role text := public.current_user_role();
  v_reschedule_rpc boolean :=
    coalesce(current_setting('app.visitor_reschedule_rpc', true), '') = 'on';
begin
  if old.tenant_id <> new.tenant_id then
    raise exception 'Visitor request ownership cannot be changed';
  end if;

  if old.created_at <> new.created_at then
    raise exception 'Visitor request creation time cannot be changed';
  end if;

  if v_reschedule_rpc then
    return new;
  end if;

  if v_role = 'tenant' then
    if old.status = 'pending' and new.status = 'cancelled' then
      if old.visitor_name <> new.visitor_name
        or old.relationship <> new.relationship
        or old.purpose <> new.purpose
        or old.contact_number <> new.contact_number
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

revoke all on function public.protect_tenant_visitor_update()
  from public, anon, authenticated;

create or replace function public.reschedule_visitor_request(
  p_request_id uuid,
  p_expected_updated_at timestamptz,
  p_schedule timestamptz,
  p_departure timestamptz,
  p_note text,
  p_keep_approval boolean default false
)
returns public.visitor_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_role text := public.current_user_role();
  v_request public.visitor_requests;
  v_keep_approval boolean := false;
begin
  if v_actor_id is null then
    raise exception 'Authentication is required';
  end if;

  select * into v_request
  from public.visitor_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Visitor request not found';
  end if;

  if not (
    (v_role = 'tenant' and v_request.tenant_id = v_actor_id)
    or public.is_staff()
  ) then
    raise exception 'You cannot change this visitor request';
  end if;

  if v_request.status not in ('pending', 'approved') then
    raise exception 'Only upcoming visitor requests can be rescheduled';
  end if;

  if p_expected_updated_at is null
     or v_request.updated_at is distinct from p_expected_updated_at then
    raise exception 'This visitor request changed. Refresh it and try again';
  end if;

  if char_length(btrim(coalesce(p_note, ''))) not between 5 and 500 then
    raise exception 'Explain the schedule change in 5 to 500 characters';
  end if;

  if p_schedule is null or p_departure is null then
    raise exception 'Arrival and departure are required';
  end if;

  if p_schedule = v_request.schedule
     and p_departure is not distinct from v_request.expected_departure_at then
    raise exception 'Choose a different arrival or departure time';
  end if;

  -- Only authorized staff can explicitly retain an existing approval.
  v_keep_approval :=
    public.is_staff()
    and v_request.status = 'approved'
    and coalesce(p_keep_approval, false);

  perform set_config('app.visitor_reschedule_rpc', 'on', true);
  perform set_config('app.visitor_schedule_note', btrim(p_note), true);

  if v_keep_approval then
    update public.visitor_requests
    set schedule = p_schedule,
        expected_departure_at = p_departure
    where id = p_request_id
    returning * into v_request;
  else
    update public.visitor_requests
    set schedule = p_schedule,
        expected_departure_at = p_departure,
        status = 'pending',
        review_note = null,
        decided_by = null,
        decided_at = null
    where id = p_request_id
    returning * into v_request;
  end if;

  return v_request;
end;
$$;

revoke all on function public.reschedule_visitor_request(
  uuid,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  boolean
) from public, anon;

grant execute on function public.reschedule_visitor_request(
  uuid,
  timestamptz,
  timestamptz,
  timestamptz,
  text,
  boolean
) to authenticated;

create or replace function public.audit_visitor_schedule_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_note text := nullif(
    btrim(coalesce(current_setting('app.visitor_schedule_note', true), '')),
    ''
  );
begin
  if new.schedule is not distinct from old.schedule
     and new.expected_departure_at is not distinct from old.expected_departure_at then
    return new;
  end if;

  if v_actor_id is null then
    return new;
  end if;

  insert into public.visitor_events(
    request_id,
    event_type,
    actor_id,
    note,
    details
  ) values (
    new.id,
    'rescheduled',
    v_actor_id,
    coalesce(v_note, 'Visitor schedule updated'),
    jsonb_build_object(
      'previous_arrival', old.schedule,
      'previous_departure', old.expected_departure_at,
      'arrival', new.schedule,
      'departure', new.expected_departure_at,
      'previous_status', old.status,
      'new_status', new.status,
      'approval_retained', old.status = 'approved' and new.status = 'approved'
    )
  );

  return new;
end;
$$;

revoke all on function public.audit_visitor_schedule_change()
  from public, anon, authenticated;

drop trigger if exists audit_visitor_schedule_change
  on public.visitor_requests;

create trigger audit_visitor_schedule_change
after update of schedule, expected_departure_at
on public.visitor_requests
for each row
execute function public.audit_visitor_schedule_change();

-- Centralize visitor notifications for request submission, staff decisions and
-- schedule changes. Notifications point to the exact request and are queued by
-- the Phase 1 server-push pipeline through server_push=true.
create or replace function public.notify_visitor_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_title text;
  v_body text;
begin
  if tg_op = 'INSERT' then
    v_title := 'New visitor request';
    v_body := 'A visitor request needs staff review.';
  elsif new.schedule is distinct from old.schedule
        or new.expected_departure_at is distinct from old.expected_departure_at then
    v_title := 'Visitor schedule changed';
    v_body := case
      when new.status = 'approved'
        then 'Authorized staff updated the approved visit schedule. Open to review the change.'
      else 'The revised visit schedule needs staff approval. Open to review.'
    end;
  elsif new.status is distinct from old.status then
    v_title := 'Visitor request update';
    v_body := 'Visitor status is now '
      || replace(initcap(new.status), '_', ' ')
      || '. Open to view the request.';
  else
    return new;
  end if;

  insert into public.app_notifications(
    recipient_id,
    notification_type,
    title,
    body,
    route_type,
    route_id,
    data
  )
  select
    profile.id,
    'visitor',
    v_title,
    v_body,
    'visitor',
    new.id,
    jsonb_build_object(
      'request_id', new.id,
      'server_push', true
    )
  from public.profiles profile
  where profile.id is distinct from v_actor_id
    and (
      profile.id = new.tenant_id
      or profile.role::text in ('owner', 'caretaker')
    );

  return new;
end;
$$;

revoke all on function public.notify_visitor_change()
  from public, anon, authenticated;

drop trigger if exists visitor_change_notification
  on public.visitor_requests;

create trigger visitor_change_notification
after insert or update
on public.visitor_requests
for each row
execute function public.notify_visitor_change();

-- Reminder log makes each stage idempotent for a specific schedule. A later
-- reschedule naturally gets a new reminder key without deleting history.
create table if not exists private.visitor_reminder_log (
  request_id uuid not null references public.visitor_requests(id) on delete cascade,
  stage text not null check (
    stage in ('arrival_reminder', 'departure_reminder', 'departure_unconfirmed')
  ),
  schedule timestamptz not null,
  departure timestamptz not null,
  created_at timestamptz not null default now(),
  primary key (request_id, stage, schedule, departure)
);

revoke all on private.visitor_reminder_log
  from public, anon, authenticated;

grant all on private.visitor_reminder_log to service_role;

create or replace function public.process_visitor_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.visitor_requests;
  v_stage text;
  v_title text;
  v_body text;
  v_count integer := 0;
begin
  for v_request in
    select request.*
    from public.visitor_requests request
    where
      (
        request.status = 'approved'
        and request.schedule > now()
        and request.schedule <= now() + interval '30 minutes'
      )
      or
      (
        request.status = 'arrived'
        and request.expected_departure_at is not null
        and request.expected_departure_at <= now() + interval '30 minutes'
      )
  loop
    if v_request.status = 'approved' then
      v_stage := 'arrival_reminder';
      v_title := 'Visitor arrival reminder';
      v_body := 'An approved visitor is expected within 30 minutes. Open to review the schedule.';
    elsif v_request.expected_departure_at <= now() then
      v_stage := 'departure_unconfirmed';
      v_title := 'Departure unconfirmed';
      v_body := 'The expected visitor departure time has passed. Authorized staff still needs to confirm checkout.';
    else
      v_stage := 'departure_reminder';
      v_title := 'Visitor departure reminder';
      v_body := 'The expected visitor departure is within 30 minutes. Open to review the visit.';
    end if;

    insert into private.visitor_reminder_log(
      request_id,
      stage,
      schedule,
      departure
    ) values (
      v_request.id,
      v_stage,
      v_request.schedule,
      v_request.expected_departure_at
    ) on conflict do nothing;

    if not found then
      continue;
    end if;

    insert into public.app_notifications(
      recipient_id,
      notification_type,
      title,
      body,
      route_type,
      route_id,
      data
    )
    select
      profile.id,
      'visitor',
      v_title,
      v_body,
      'visitor',
      v_request.id,
      jsonb_build_object(
        'request_id', v_request.id,
        'stage', v_stage,
        'server_push', true
      )
    from public.profiles profile
    where profile.id = v_request.tenant_id
       or profile.role::text in ('owner', 'caretaker');

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.process_visitor_reminders()
  from public, anon, authenticated;
grant execute on function public.process_visitor_reminders()
  to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
declare
  v_job record;
begin
  for v_job in
    select jobid from cron.job where jobname = 'visitor-reminders'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  perform cron.schedule(
    'visitor-reminders',
    '*/5 * * * *',
    'select public.process_visitor_reminders();'
  );
end $$;

commit;
