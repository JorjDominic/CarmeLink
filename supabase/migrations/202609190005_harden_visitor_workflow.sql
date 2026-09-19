-- Harden visitor requests and add an append-only arrival/departure history.
-- Neutral presence terminology is intentional: this workflow does not assume
-- a staffed gate or any dedicated access-control device.

alter table public.visitor_requests
  drop constraint if exists visitor_requests_status_check;

alter table public.visitor_requests
  add constraint visitor_requests_status_check
  check (status in (
    'pending',
    'approved',
    'rejected',
    'cancelled',
    'arrived',
    'completed'
  ));

alter table public.visitor_requests
  add column if not exists review_note text,
  add column if not exists decided_by uuid references public.profiles(id),
  add column if not exists decided_at timestamptz,
  add column if not exists arrived_at timestamptz,
  add column if not exists departed_at timestamptz;

alter table public.visitor_requests
  add constraint visitor_requests_schedule_after_creation_check
  check (schedule > created_at),
  add constraint visitor_requests_review_note_length_check
  check (review_note is null or char_length(trim(review_note)) between 2 and 500),
  add constraint visitor_requests_decision_consistency_check
  check (
    (status in ('approved', 'rejected', 'arrived', 'completed')
      and decided_by is not null and decided_at is not null)
    or
    (status in ('pending', 'cancelled')
      and decided_by is null and decided_at is null)
  ),
  add constraint visitor_requests_arrival_consistency_check
  check (
    (status in ('arrived', 'completed') and arrived_at is not null)
    or
    (status not in ('arrived', 'completed') and arrived_at is null)
  ),
  add constraint visitor_requests_departure_consistency_check
  check (
    (status = 'completed' and departed_at is not null)
    or
    (status <> 'completed' and departed_at is null)
  ),
  add constraint visitor_requests_event_order_check
  check (
    (arrived_at is null or arrived_at >= decided_at)
    and (departed_at is null or departed_at >= arrived_at)
  );

create index if not exists visitor_requests_review_queue_idx
  on public.visitor_requests (status, schedule);

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
        or old.schedule <> new.schedule then
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

create table public.visitor_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null
    references public.visitor_requests(id) on delete restrict,
  event_type text not null
    check (event_type in (
      'approved', 'rejected', 'cancelled', 'arrived', 'departed'
    )),
  actor_id uuid not null
    references public.profiles(id) on delete restrict,
  note text,
  occurred_at timestamptz not null default now(),
  check (note is null or char_length(trim(note)) between 2 and 500)
);

create index visitor_events_request_timeline_idx
  on public.visitor_events (request_id, occurred_at desc);

create index visitor_events_actor_idx
  on public.visitor_events (actor_id);

alter table public.visitor_events enable row level security;

create policy "tenants read events for own visitor requests"
on public.visitor_events
for select
to authenticated
using (
  exists (
    select 1
    from public.visitor_requests request
    where request.id = visitor_events.request_id
      and request.tenant_id = (select auth.uid())
  )
);

create policy "staff read visitor events"
on public.visitor_events
for select
to authenticated
using ((select public.is_staff()));

revoke all on table public.visitor_events from public, anon, authenticated;
grant select on table public.visitor_events to authenticated;

-- Staff changes must go through the transition function below. Direct staff
-- updates previously allowed ownership, schedule, and arbitrary status edits.
drop policy if exists "staff update visitor requests"
  on public.visitor_requests;

-- Cancellation must be retained for audit history rather than deleting the row.
drop policy if exists "tenants delete own pending visitor requests"
  on public.visitor_requests;

revoke delete on table public.visitor_requests from authenticated;

create or replace function public.transition_visitor_request(
  p_request_id uuid,
  p_action text,
  p_note text default null
)
returns public.visitor_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text := public.current_user_role();
  v_request public.visitor_requests;
  v_now timestamptz := now();
  v_event_type text;
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

  if p_action = 'cancel' then
    if v_actor_role <> 'tenant' or v_request.tenant_id <> v_actor_id then
      raise exception 'Only the requesting tenant can cancel this request';
    end if;
    if v_request.status <> 'pending' then
      raise exception 'Only pending visitor requests can be cancelled';
    end if;

    update public.visitor_requests
    set status = 'cancelled'
    where id = p_request_id
    returning * into v_request;
    v_event_type := 'cancelled';
  else
    if not public.is_staff() then
      raise exception 'Only authorized staff can perform this action';
    end if;

    case p_action
      when 'approve' then
        if v_request.status <> 'pending' then
          raise exception 'Only pending visitor requests can be approved';
        end if;
        update public.visitor_requests
        set status = 'approved',
            review_note = nullif(trim(p_note), ''),
            decided_by = v_actor_id,
            decided_at = v_now
        where id = p_request_id
        returning * into v_request;
        v_event_type := 'approved';

      when 'reject' then
        if v_request.status <> 'pending' then
          raise exception 'Only pending visitor requests can be rejected';
        end if;
        if p_note is null or char_length(trim(p_note)) < 2 then
          raise exception 'A rejection reason is required';
        end if;
        update public.visitor_requests
        set status = 'rejected',
            review_note = trim(p_note),
            decided_by = v_actor_id,
            decided_at = v_now
        where id = p_request_id
        returning * into v_request;
        v_event_type := 'rejected';

      when 'record_arrival' then
        if v_request.status <> 'approved' then
          raise exception 'Only approved visitor requests can record arrival';
        end if;
        update public.visitor_requests
        set status = 'arrived', arrived_at = v_now
        where id = p_request_id
        returning * into v_request;
        v_event_type := 'arrived';

      when 'record_departure' then
        if v_request.status <> 'arrived' then
          raise exception 'Departure requires a recorded arrival';
        end if;
        update public.visitor_requests
        set status = 'completed', departed_at = v_now
        where id = p_request_id
        returning * into v_request;
        v_event_type := 'departed';

      else
        raise exception 'Unsupported visitor request action';
    end case;
  end if;

  insert into public.visitor_events (
    request_id, event_type, actor_id, note, occurred_at
  ) values (
    p_request_id, v_event_type, v_actor_id, nullif(trim(p_note), ''), v_now
  );

  return v_request;
end;
$$;

revoke all on function public.transition_visitor_request(uuid, text, text)
  from public, anon;
grant execute on function public.transition_visitor_request(uuid, text, text)
  to authenticated;

-- Direct inserts/updates/deletes would bypass the append-only audit history.
revoke insert, update, delete on table public.visitor_events
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visitor_requests'
  ) then
    alter publication supabase_realtime add table public.visitor_requests;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'visitor_events'
  ) then
    alter publication supabase_realtime add table public.visitor_events;
  end if;
end;
$$;
