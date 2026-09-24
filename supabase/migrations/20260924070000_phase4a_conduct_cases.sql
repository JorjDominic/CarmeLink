begin;

-- Phase 4A: Conduct & Cases
--
-- Source-grounded boundaries:
--   * incidents/cases, evidence, tenant responses, warnings, repeat history
--   * termination REVIEW recommendation only
--   * restricted owner/caretaker access
--   * tenant sees only the tenant-safe view of their own published cases
--
-- This migration MUST NOT:
--   * create a penalty/damage/payment charge
--   * change a contract, room/bed assignment, account status, or tenancy status
--   * evict/terminate a tenant automatically
--   * expose a confidential reporter/source identity to the accused tenant
--
-- Cross-module financial/lifecycle decisions remain a separate Leader Developer
-- workflow.

create table public.conduct_cases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null
    references public.profiles(id) on delete restrict,
  category text not null
    check (
      category in (
        'rule_violation',
        'misconduct',
        'unauthorized_visitor',
        'roommate_conflict',
        'safety',
        'property_damage',
        'curfew',
        'other'
      )
    ),
  title text not null
    check (char_length(trim(title)) between 3 and 160),
  description text not null
    check (char_length(trim(description)) between 10 and 4000),
  incident_at timestamptz not null,
  status text not null default 'draft'
    check (
      status in (
        'draft',
        'awaiting_response',
        'under_review',
        'warning_issued',
        'resolved',
        'dismissed',
        'termination_review_recommended'
      )
    ),
  source_module text not null default 'manual'
    check (
      source_module in (
        'manual',
        'confidential_report',
        'room_inspection',
        'cleaning_report',
        'curfew',
        'visitor',
        'maintenance',
        'other'
      )
    ),
  source_record_id text,
  tenant_notified_at timestamptz,
  resolution_notes text not null default ''
    check (char_length(resolution_notes) <= 4000),
  termination_review_reason text not null default ''
    check (char_length(termination_review_reason) <= 4000),
  opened_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index conduct_cases_tenant_idx
  on public.conduct_cases(tenant_id, created_at desc);
create index conduct_cases_status_idx
  on public.conduct_cases(status, updated_at desc);
create index conduct_cases_source_idx
  on public.conduct_cases(source_module, source_record_id);

create trigger conduct_cases_set_updated_at
before update on public.conduct_cases
for each row
execute function public.set_updated_at();

alter table public.conduct_cases enable row level security;
revoke all on public.conduct_cases from anon, authenticated;
grant select on public.conduct_cases to authenticated;

create policy "staff read conduct cases"
on public.conduct_cases
for select
to authenticated
using ((select public.is_staff()));

create table public.conduct_case_responses (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    references public.conduct_cases(id) on delete cascade,
  tenant_id uuid not null
    references public.profiles(id) on delete restrict,
  body text not null
    check (char_length(trim(body)) between 5 and 4000),
  created_at timestamptz not null default now()
);

create index conduct_case_responses_case_idx
  on public.conduct_case_responses(case_id, created_at);
create index conduct_case_responses_tenant_idx
  on public.conduct_case_responses(tenant_id, created_at desc);

alter table public.conduct_case_responses enable row level security;
revoke all on public.conduct_case_responses from anon, authenticated;
grant select on public.conduct_case_responses to authenticated;

create policy "staff read conduct responses"
on public.conduct_case_responses
for select
to authenticated
using ((select public.is_staff()));

create table public.conduct_case_warnings (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    references public.conduct_cases(id) on delete cascade,
  message text not null
    check (char_length(trim(message)) between 5 and 3000),
  issued_by uuid not null
    references public.profiles(id) on delete restrict,
  issued_at timestamptz not null default now()
);

create index conduct_case_warnings_case_idx
  on public.conduct_case_warnings(case_id, issued_at desc);

alter table public.conduct_case_warnings enable row level security;
revoke all on public.conduct_case_warnings from anon, authenticated;
grant select on public.conduct_case_warnings to authenticated;

create policy "staff read conduct warnings"
on public.conduct_case_warnings
for select
to authenticated
using ((select public.is_staff()));

create table public.conduct_case_events (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    references public.conduct_cases(id) on delete cascade,
  event_type text not null
    check (
      event_type in (
        'case_created',
        'tenant_notified',
        'tenant_response_submitted',
        'review_started',
        'warning_issued',
        'resolved',
        'dismissed',
        'termination_review_recommended',
        'evidence_added'
      )
    ),
  actor_id uuid
    references public.profiles(id) on delete set null,
  actor_name text not null,
  notes text not null default ''
    check (char_length(notes) <= 4000),
  created_at timestamptz not null default now()
);

create index conduct_case_events_case_idx
  on public.conduct_case_events(case_id, created_at);

alter table public.conduct_case_events enable row level security;
revoke all on public.conduct_case_events from anon, authenticated;
grant select on public.conduct_case_events to authenticated;

create policy "staff read conduct case events"
on public.conduct_case_events
for select
to authenticated
using ((select public.is_staff()));

create table public.conduct_case_evidence (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    references public.conduct_cases(id) on delete cascade,
  storage_path text not null unique,
  original_name text not null,
  content_type text not null,
  size_bytes bigint not null
    check (size_bytes > 0 and size_bytes <= 10485760),
  caption text not null default ''
    check (char_length(caption) <= 1000),
  uploaded_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index conduct_case_evidence_case_idx
  on public.conduct_case_evidence(case_id, created_at desc);

alter table public.conduct_case_evidence enable row level security;
revoke all on public.conduct_case_evidence from anon, authenticated;
grant select on public.conduct_case_evidence to authenticated;

create policy "staff read conduct evidence metadata"
on public.conduct_case_evidence
for select
to authenticated
using ((select public.is_staff()));

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'conduct_case_evidence',
  'conduct_case_evidence',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "staff read conduct evidence files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'conduct_case_evidence'
  and (select public.is_staff())
);

create policy "staff upload conduct evidence files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'conduct_case_evidence'
  and (select public.is_staff())
);

create policy "staff update conduct evidence files"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'conduct_case_evidence'
  and (select public.is_staff())
)
with check (
  bucket_id = 'conduct_case_evidence'
  and (select public.is_staff())
);

create policy "staff delete conduct evidence files"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'conduct_case_evidence'
  and (select public.is_staff())
);

create or replace function public.conduct_actor_name()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select nullif(trim(full_name), '')
      from public.profiles
      where id = (select auth.uid())
    ),
    'Authorized user'
  );
$$;

revoke all on function public.conduct_actor_name()
  from public, anon, authenticated;
grant execute on function public.conduct_actor_name()
  to authenticated;

create or replace function public.create_conduct_case(
  p_tenant_id uuid,
  p_category text,
  p_title text,
  p_description text,
  p_incident_at timestamptz,
  p_source_module text default 'manual',
  p_source_record_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case_id uuid;
  v_title text := trim(coalesce(p_title, ''));
  v_description text := trim(coalesce(p_description, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may create conduct cases'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_tenant_id
      and role = 'tenant'
  ) then
    raise exception 'Selected tenant was not found';
  end if;

  if p_category not in (
    'rule_violation',
    'misconduct',
    'unauthorized_visitor',
    'roommate_conflict',
    'safety',
    'property_damage',
    'curfew',
    'other'
  ) then
    raise exception 'Invalid conduct case category';
  end if;

  if p_source_module not in (
    'manual',
    'confidential_report',
    'room_inspection',
    'cleaning_report',
    'curfew',
    'visitor',
    'maintenance',
    'other'
  ) then
    raise exception 'Invalid conduct case source';
  end if;

  if char_length(v_title) < 3 or char_length(v_title) > 160 then
    raise exception 'Case title must be between 3 and 160 characters';
  end if;

  if char_length(v_description) < 10
     or char_length(v_description) > 4000 then
    raise exception 'Case description must be between 10 and 4000 characters';
  end if;

  if p_incident_at > now() + interval '5 minutes' then
    raise exception 'Incident time cannot be in the future';
  end if;

  insert into public.conduct_cases (
    tenant_id,
    category,
    title,
    description,
    incident_at,
    source_module,
    source_record_id,
    opened_by
  )
  values (
    p_tenant_id,
    p_category,
    v_title,
    v_description,
    p_incident_at,
    p_source_module,
    nullif(trim(coalesce(p_source_record_id, '')), ''),
    v_actor
  )
  returning id into v_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    v_case_id,
    'case_created',
    v_actor,
    public.conduct_actor_name(),
    'Restricted conduct case created as draft.'
  );

  return v_case_id;
end;
$$;

revoke all on function public.create_conduct_case(
  uuid, text, text, text, timestamptz, text, text
) from public, anon;
grant execute on function public.create_conduct_case(
  uuid, text, text, text, timestamptz, text, text
) to authenticated;

create or replace function public.publish_conduct_case(
  p_case_id uuid,
  p_expected_updated_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_case public.conduct_cases%rowtype;
  v_actor uuid := auth.uid();
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may publish conduct cases'
      using errcode = '42501';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Conduct case not found';
  end if;

  if p_expected_updated_at is null
     or v_case.updated_at is distinct from p_expected_updated_at then
    raise exception 'This conduct case changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_case.status <> 'draft' then
    raise exception 'Only draft conduct cases can be published';
  end if;

  update public.conduct_cases
  set
    status = 'awaiting_response',
    tenant_notified_at = now()
  where id = p_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    'tenant_notified',
    v_actor,
    public.conduct_actor_name(),
    'Case was published to the affected tenant for response.'
  );
end;
$$;

revoke all on function public.publish_conduct_case(uuid, timestamptz)
  from public, anon;
grant execute on function public.publish_conduct_case(uuid, timestamptz)
  to authenticated;

create or replace function public.submit_conduct_case_response(
  p_case_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.conduct_cases%rowtype;
  v_body text := trim(coalesce(p_body, ''));
  v_response_id uuid;
begin
  if v_actor is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id
  for update;

  if not found
     or v_case.tenant_id <> v_actor
     or v_case.tenant_notified_at is null then
    raise exception 'This conduct case is not available to your account'
      using errcode = '42501';
  end if;

  if v_case.status in ('draft', 'resolved', 'dismissed') then
    raise exception 'Responses are closed for this conduct case';
  end if;

  if char_length(v_body) < 5 or char_length(v_body) > 4000 then
    raise exception 'Response must be between 5 and 4000 characters';
  end if;

  insert into public.conduct_case_responses (
    case_id,
    tenant_id,
    body
  )
  values (
    p_case_id,
    v_actor,
    v_body
  )
  returning id into v_response_id;

  if v_case.status = 'awaiting_response' then
    update public.conduct_cases
    set status = 'under_review'
    where id = p_case_id;
  end if;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    'tenant_response_submitted',
    v_actor,
    public.conduct_actor_name(),
    'Affected tenant submitted a response.'
  );

  return v_response_id;
end;
$$;

revoke all on function public.submit_conduct_case_response(uuid, text)
  from public, anon;
grant execute on function public.submit_conduct_case_response(uuid, text)
  to authenticated;

create or replace function public.issue_conduct_case_warning(
  p_case_id uuid,
  p_expected_updated_at timestamptz,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.conduct_cases%rowtype;
  v_message text := trim(coalesce(p_message, ''));
  v_warning_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may issue conduct warnings'
      using errcode = '42501';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Conduct case not found';
  end if;

  if p_expected_updated_at is null
     or v_case.updated_at is distinct from p_expected_updated_at then
    raise exception 'This conduct case changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_case.status in ('draft', 'resolved', 'dismissed') then
    raise exception 'A warning cannot be issued in the current case state';
  end if;

  if char_length(v_message) < 5 or char_length(v_message) > 3000 then
    raise exception 'Warning must be between 5 and 3000 characters';
  end if;

  insert into public.conduct_case_warnings (
    case_id,
    message,
    issued_by
  )
  values (
    p_case_id,
    v_message,
    v_actor
  )
  returning id into v_warning_id;

  update public.conduct_cases
  set status = 'warning_issued'
  where id = p_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    'warning_issued',
    v_actor,
    public.conduct_actor_name(),
    v_message
  );

  return v_warning_id;
end;
$$;

revoke all on function public.issue_conduct_case_warning(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.issue_conduct_case_warning(
  uuid, timestamptz, text
) to authenticated;

create or replace function public.set_conduct_case_review_status(
  p_case_id uuid,
  p_expected_updated_at timestamptz,
  p_status text,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.conduct_cases%rowtype;
  v_notes text := trim(coalesce(p_notes, ''));
  v_event_type text;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may review conduct cases'
      using errcode = '42501';
  end if;

  if p_status not in ('under_review', 'resolved', 'dismissed') then
    raise exception 'Invalid conduct review status';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Conduct case not found';
  end if;

  if p_expected_updated_at is null
     or v_case.updated_at is distinct from p_expected_updated_at then
    raise exception 'This conduct case changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_case.status = 'draft' then
    raise exception 'Publish the conduct case before reviewing it';
  end if;

  if v_case.status in ('resolved', 'dismissed') then
    raise exception 'Closed conduct cases cannot be changed';
  end if;

  if p_status in ('resolved', 'dismissed')
     and char_length(v_notes) < 5 then
    raise exception 'Resolution or dismissal notes must contain at least 5 characters';
  end if;

  if char_length(v_notes) > 4000 then
    raise exception 'Review notes must be 4000 characters or fewer';
  end if;

  v_event_type := case p_status
    when 'resolved' then 'resolved'
    when 'dismissed' then 'dismissed'
    else 'review_started'
  end;

  update public.conduct_cases
  set
    status = p_status,
    resolution_notes = case
      when p_status in ('resolved', 'dismissed') then v_notes
      else resolution_notes
    end
  where id = p_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    v_event_type,
    v_actor,
    public.conduct_actor_name(),
    v_notes
  );
end;
$$;

revoke all on function public.set_conduct_case_review_status(
  uuid, timestamptz, text, text
) from public, anon;
grant execute on function public.set_conduct_case_review_status(
  uuid, timestamptz, text, text
) to authenticated;

create or replace function public.recommend_conduct_termination_review(
  p_case_id uuid,
  p_expected_updated_at timestamptz,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.conduct_cases%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may recommend termination review'
      using errcode = '42501';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id
  for update;

  if not found then
    raise exception 'Conduct case not found';
  end if;

  if p_expected_updated_at is null
     or v_case.updated_at is distinct from p_expected_updated_at then
    raise exception 'This conduct case changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_case.status in ('draft', 'resolved', 'dismissed') then
    raise exception 'Termination review cannot be recommended in the current case state';
  end if;

  if char_length(v_reason) < 10 or char_length(v_reason) > 4000 then
    raise exception 'Termination review reason must be between 10 and 4000 characters';
  end if;

  update public.conduct_cases
  set
    status = 'termination_review_recommended',
    termination_review_reason = v_reason
  where id = p_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    'termination_review_recommended',
    v_actor,
    public.conduct_actor_name(),
    v_reason
  );

  -- Intentionally NO contract/account/assignment/occupancy mutation here.
end;
$$;

revoke all on function public.recommend_conduct_termination_review(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.recommend_conduct_termination_review(
  uuid, timestamptz, text
) to authenticated;

create or replace function public.register_conduct_case_evidence(
  p_case_id uuid,
  p_storage_path text,
  p_original_name text,
  p_content_type text,
  p_size_bytes bigint,
  p_caption text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_caption text := trim(coalesce(p_caption, ''));
  v_evidence_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may attach conduct evidence'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.conduct_cases
    where id = p_case_id
  ) then
    raise exception 'Conduct case not found';
  end if;

  if trim(coalesce(p_storage_path, '')) = '' then
    raise exception 'Evidence storage path is required';
  end if;

  if trim(coalesce(p_original_name, '')) = '' then
    raise exception 'Evidence file name is required';
  end if;

  if p_content_type not in ('image/jpeg', 'image/png', 'image/webp') then
    raise exception 'Unsupported evidence file type';
  end if;

  if p_size_bytes <= 0 or p_size_bytes > 10485760 then
    raise exception 'Evidence image must be 10 MB or smaller';
  end if;

  if char_length(v_caption) > 1000 then
    raise exception 'Evidence caption must be 1000 characters or fewer';
  end if;

  insert into public.conduct_case_evidence (
    case_id,
    storage_path,
    original_name,
    content_type,
    size_bytes,
    caption,
    uploaded_by
  )
  values (
    p_case_id,
    p_storage_path,
    p_original_name,
    p_content_type,
    p_size_bytes,
    v_caption,
    v_actor
  )
  returning id into v_evidence_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    p_case_id,
    'evidence_added',
    v_actor,
    public.conduct_actor_name(),
    case when v_caption = '' then 'Evidence image attached.' else v_caption end
  );

  return v_evidence_id;
end;
$$;

revoke all on function public.register_conduct_case_evidence(
  uuid, text, text, text, bigint, text
) from public, anon;
grant execute on function public.register_conduct_case_evidence(
  uuid, text, text, text, bigint, text
) to authenticated;

-- Tenant-safe reads. These intentionally do not return source_module,
-- source_record_id, opened_by, or evidence metadata.
create or replace function public.get_my_conduct_cases()
returns table (
  id uuid,
  category text,
  title text,
  description text,
  incident_at timestamptz,
  status text,
  tenant_notified_at timestamptz,
  resolution_notes text,
  termination_review_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.category,
    c.title,
    c.description,
    c.incident_at,
    c.status,
    c.tenant_notified_at,
    c.resolution_notes,
    c.termination_review_reason,
    c.created_at,
    c.updated_at
  from public.conduct_cases c
  where c.tenant_id = (select auth.uid())
    and c.tenant_notified_at is not null
  order by c.created_at desc;
$$;

revoke all on function public.get_my_conduct_cases()
  from public, anon;
grant execute on function public.get_my_conduct_cases()
  to authenticated;

create or replace function public.get_my_conduct_case_responses(
  p_case_id uuid
)
returns table (
  id uuid,
  body text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    r.id,
    r.body,
    r.created_at
  from public.conduct_case_responses r
  join public.conduct_cases c on c.id = r.case_id
  where r.case_id = p_case_id
    and c.tenant_id = (select auth.uid())
    and c.tenant_notified_at is not null
  order by r.created_at;
$$;

revoke all on function public.get_my_conduct_case_responses(uuid)
  from public, anon;
grant execute on function public.get_my_conduct_case_responses(uuid)
  to authenticated;

create or replace function public.get_my_conduct_case_warnings(
  p_case_id uuid
)
returns table (
  id uuid,
  message text,
  issued_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    w.id,
    w.message,
    w.issued_at
  from public.conduct_case_warnings w
  join public.conduct_cases c on c.id = w.case_id
  where w.case_id = p_case_id
    and c.tenant_id = (select auth.uid())
    and c.tenant_notified_at is not null
  order by w.issued_at desc;
$$;

revoke all on function public.get_my_conduct_case_warnings(uuid)
  from public, anon;
grant execute on function public.get_my_conduct_case_warnings(uuid)
  to authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'conduct_cases',
    'conduct_case_responses',
    'conduct_case_warnings',
    'conduct_case_events',
    'conduct_case_evidence'
  ] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end $$;

commit;
