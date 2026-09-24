begin;

-- Phase 3B: Room Inspections
--
-- Implements:
--   * monthly room inspections with a minimum three-day written notice
--   * staff-started inspection sessions
--   * structured findings and corrective actions
--   * staff-only evidence photos
--   * completed inspection summaries
--   * follow-up inspections linked to a completed parent inspection
--   * tenant read-only visibility for inspections/notices/findings in their
--     currently assigned room
--
-- Deliberately excluded:
--   * move-in condition snapshots (client approval still pending)
--   * move-out/final-inspection lifecycle transitions
--   * automatic maintenance work orders
--   * disciplinary cases, penalties, damages, deposit deductions, or billing
--
-- Those remain separate linked workflows and must never be merged into an
-- inspection row.

create table public.room_inspections (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null
    references public.rooms(id) on delete restrict,
  inspection_type text not null
    check (
      inspection_type in (
        'monthly',
        'follow_up',
        'move_in',
        'move_out',
        'emergency'
      )
    ),
  parent_inspection_id uuid
    references public.room_inspections(id) on delete set null,
  status text not null default 'scheduled'
    check (
      status in (
        'scheduled',
        'in_progress',
        'completed',
        'cancelled'
      )
    ),
  scheduled_at timestamptz not null,
  notice_text text not null default ''
    check (char_length(notice_text) <= 2000),
  notice_published_at timestamptz,
  summary text not null default ''
    check (char_length(summary) <= 4000),
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text not null default ''
    check (char_length(cancellation_reason) <= 1000),
  created_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    inspection_type <> 'follow_up'
    or parent_inspection_id is not null
  ),
  check (
    inspection_type = 'follow_up'
    or parent_inspection_id is null
  )
);

create index room_inspections_room_schedule_idx
  on public.room_inspections(room_id, scheduled_at desc);
create index room_inspections_status_idx
  on public.room_inspections(status, scheduled_at);
create index room_inspections_parent_idx
  on public.room_inspections(parent_inspection_id);

create trigger room_inspections_set_updated_at
before update on public.room_inspections
for each row
execute function public.set_updated_at();

alter table public.room_inspections enable row level security;

revoke all on public.room_inspections from anon, authenticated;
grant select on public.room_inspections to authenticated;

create policy "staff read room inspections"
on public.room_inspections
for select
to authenticated
using ((select public.is_staff()));

create policy "tenant read current room inspections"
on public.room_inspections
for select
to authenticated
using (
  room_id = public.current_tenant_room_id()
  and notice_published_at is not null
);

create table public.room_inspection_findings (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null
    references public.room_inspections(id) on delete cascade,
  category text not null
    check (
      category in (
        'condition',
        'cleanliness',
        'maintenance',
        'safety',
        'furniture',
        'utilities',
        'other'
      )
    ),
  location_label text not null
    check (
      char_length(trim(location_label)) between 2 and 120
    ),
  severity text not null
    check (
      severity in ('note', 'minor', 'moderate', 'major')
    ),
  description text not null
    check (
      char_length(trim(description)) between 5 and 2000
    ),
  corrective_action text not null default ''
    check (char_length(corrective_action) <= 2000),
  action_due_at timestamptz,
  status text not null default 'open'
    check (
      status in ('open', 'monitoring', 'corrected')
    ),
  corrected_at timestamptz,
  created_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index room_inspection_findings_inspection_idx
  on public.room_inspection_findings(inspection_id, created_at);
create index room_inspection_findings_status_idx
  on public.room_inspection_findings(status, action_due_at);

create trigger room_inspection_findings_set_updated_at
before update on public.room_inspection_findings
for each row
execute function public.set_updated_at();

alter table public.room_inspection_findings enable row level security;

revoke all on public.room_inspection_findings from anon, authenticated;
grant select on public.room_inspection_findings to authenticated;

create policy "staff read inspection findings"
on public.room_inspection_findings
for select
to authenticated
using ((select public.is_staff()));

create policy "tenant read findings for current room"
on public.room_inspection_findings
for select
to authenticated
using (
  exists (
    select 1
    from public.room_inspections inspection
    where inspection.id = inspection_id
      and inspection.room_id = public.current_tenant_room_id()
      and inspection.notice_published_at is not null
  )
);

create table public.room_inspection_evidence (
  id uuid primary key default gen_random_uuid(),
  inspection_id uuid not null
    references public.room_inspections(id) on delete cascade,
  finding_id uuid
    references public.room_inspection_findings(id) on delete cascade,
  storage_path text not null unique,
  original_name text not null,
  content_type text not null,
  size_bytes bigint not null
    check (size_bytes > 0 and size_bytes <= 10485760),
  uploaded_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index room_inspection_evidence_inspection_idx
  on public.room_inspection_evidence(inspection_id, created_at);
create index room_inspection_evidence_finding_idx
  on public.room_inspection_evidence(finding_id, created_at);

alter table public.room_inspection_evidence enable row level security;

revoke all on public.room_inspection_evidence from anon, authenticated;
grant select on public.room_inspection_evidence to authenticated;

create policy "staff read inspection evidence metadata"
on public.room_inspection_evidence
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
  'room_inspection_evidence',
  'room_inspection_evidence',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "staff read room inspection evidence"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'room_inspection_evidence'
  and (select public.is_staff())
);

create policy "staff upload room inspection evidence"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'room_inspection_evidence'
  and (select public.is_staff())
);

create policy "staff update room inspection evidence"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'room_inspection_evidence'
  and (select public.is_staff())
)
with check (
  bucket_id = 'room_inspection_evidence'
  and (select public.is_staff())
);

create policy "staff delete room inspection evidence"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'room_inspection_evidence'
  and (select public.is_staff())
);

create or replace function public.create_room_inspection(
  p_room_id uuid,
  p_inspection_type text,
  p_scheduled_at timestamptz,
  p_notice_text text,
  p_parent_inspection_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_notice text := trim(coalesce(p_notice_text, ''));
  v_parent public.room_inspections%rowtype;
  v_inspection_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may schedule room inspections'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.rooms
    where id = p_room_id
  ) then
    raise exception 'Room not found';
  end if;

  if p_inspection_type not in ('monthly', 'follow_up') then
    raise exception
      'Only monthly and follow-up inspections are enabled in this phase';
  end if;

  if char_length(v_notice) < 5 then
    raise exception 'Written notice must contain at least 5 characters';
  end if;

  if char_length(v_notice) > 2000 then
    raise exception 'Written notice must be 2000 characters or fewer';
  end if;

  if p_scheduled_at <= now() then
    raise exception 'Inspection schedule must be in the future';
  end if;

  if p_inspection_type = 'monthly' then
    if p_parent_inspection_id is not null then
      raise exception 'Monthly inspections cannot have a parent inspection';
    end if;

    if p_scheduled_at < now() + interval '3 days' then
      raise exception
        'Monthly inspections require at least three days written notice';
    end if;
  else
    if p_parent_inspection_id is null then
      raise exception 'A follow-up inspection must reference a completed inspection';
    end if;

    select *
      into v_parent
    from public.room_inspections
    where id = p_parent_inspection_id;

    if not found then
      raise exception 'Parent inspection not found';
    end if;

    if v_parent.room_id <> p_room_id then
      raise exception 'Follow-up inspection must use the same room';
    end if;

    if v_parent.status <> 'completed' then
      raise exception 'Follow-up inspection requires a completed parent inspection';
    end if;
  end if;

  insert into public.room_inspections (
    room_id,
    inspection_type,
    parent_inspection_id,
    status,
    scheduled_at,
    notice_text,
    notice_published_at,
    created_by
  )
  values (
    p_room_id,
    p_inspection_type,
    p_parent_inspection_id,
    'scheduled',
    p_scheduled_at,
    v_notice,
    now(),
    v_actor
  )
  returning id into v_inspection_id;

  return v_inspection_id;
end;
$$;

revoke all on function public.create_room_inspection(
  uuid, text, timestamptz, text, uuid
) from public, anon;
grant execute on function public.create_room_inspection(
  uuid, text, timestamptz, text, uuid
) to authenticated;

create or replace function public.start_room_inspection(
  p_inspection_id uuid,
  p_expected_updated_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inspection public.room_inspections%rowtype;
begin
  if auth.uid() is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may start room inspections'
      using errcode = '42501';
  end if;

  select *
    into v_inspection
  from public.room_inspections
  where id = p_inspection_id
  for update;

  if not found then
    raise exception 'Inspection not found';
  end if;

  if p_expected_updated_at is null
     or v_inspection.updated_at is distinct from p_expected_updated_at then
    raise exception 'This inspection changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_inspection.status <> 'scheduled' then
    raise exception 'Only scheduled inspections can be started';
  end if;

  if now() < v_inspection.scheduled_at then
    raise exception 'Inspection cannot start before the scheduled time';
  end if;

  update public.room_inspections
  set
    status = 'in_progress',
    started_at = now()
  where id = p_inspection_id;
end;
$$;

revoke all on function public.start_room_inspection(uuid, timestamptz)
  from public, anon;
grant execute on function public.start_room_inspection(uuid, timestamptz)
  to authenticated;

create or replace function public.add_room_inspection_finding(
  p_inspection_id uuid,
  p_category text,
  p_location_label text,
  p_severity text,
  p_description text,
  p_corrective_action text default '',
  p_action_due_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_inspection public.room_inspections%rowtype;
  v_location text := trim(coalesce(p_location_label, ''));
  v_description text := trim(coalesce(p_description, ''));
  v_action text := trim(coalesce(p_corrective_action, ''));
  v_finding_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may record inspection findings'
      using errcode = '42501';
  end if;

  select *
    into v_inspection
  from public.room_inspections
  where id = p_inspection_id;

  if not found then
    raise exception 'Inspection not found';
  end if;

  if v_inspection.status <> 'in_progress' then
    raise exception 'Findings can be added only while an inspection is in progress';
  end if;

  if p_category not in (
    'condition',
    'cleanliness',
    'maintenance',
    'safety',
    'furniture',
    'utilities',
    'other'
  ) then
    raise exception 'Invalid finding category';
  end if;

  if p_severity not in ('note', 'minor', 'moderate', 'major') then
    raise exception 'Invalid finding severity';
  end if;

  if char_length(v_location) < 2 or char_length(v_location) > 120 then
    raise exception 'Finding location must be between 2 and 120 characters';
  end if;

  if char_length(v_description) < 5
     or char_length(v_description) > 2000 then
    raise exception 'Finding description must be between 5 and 2000 characters';
  end if;

  if char_length(v_action) > 2000 then
    raise exception 'Corrective action must be 2000 characters or fewer';
  end if;

  if p_action_due_at is not null and p_action_due_at <= now() then
    raise exception 'Corrective-action due date must be in the future';
  end if;

  insert into public.room_inspection_findings (
    inspection_id,
    category,
    location_label,
    severity,
    description,
    corrective_action,
    action_due_at,
    status,
    created_by
  )
  values (
    p_inspection_id,
    p_category,
    v_location,
    p_severity,
    v_description,
    v_action,
    p_action_due_at,
    'open',
    v_actor
  )
  returning id into v_finding_id;

  return v_finding_id;
end;
$$;

revoke all on function public.add_room_inspection_finding(
  uuid, text, text, text, text, text, timestamptz
) from public, anon;
grant execute on function public.add_room_inspection_finding(
  uuid, text, text, text, text, text, timestamptz
) to authenticated;

create or replace function public.update_room_inspection_finding(
  p_finding_id uuid,
  p_expected_updated_at timestamptz,
  p_status text,
  p_corrective_action text,
  p_action_due_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_finding public.room_inspection_findings%rowtype;
  v_action text := trim(coalesce(p_corrective_action, ''));
begin
  if auth.uid() is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may update inspection findings'
      using errcode = '42501';
  end if;

  if p_status not in ('open', 'monitoring', 'corrected') then
    raise exception 'Invalid finding status';
  end if;

  if char_length(v_action) > 2000 then
    raise exception 'Corrective action must be 2000 characters or fewer';
  end if;

  select *
    into v_finding
  from public.room_inspection_findings
  where id = p_finding_id
  for update;

  if not found then
    raise exception 'Finding not found';
  end if;

  if p_expected_updated_at is null
     or v_finding.updated_at is distinct from p_expected_updated_at then
    raise exception 'This finding changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  update public.room_inspection_findings
  set
    status = p_status,
    corrective_action = v_action,
    action_due_at = p_action_due_at,
    corrected_at = case
      when p_status = 'corrected' then now()
      else null
    end
  where id = p_finding_id;
end;
$$;

revoke all on function public.update_room_inspection_finding(
  uuid, timestamptz, text, text, timestamptz
) from public, anon;
grant execute on function public.update_room_inspection_finding(
  uuid, timestamptz, text, text, timestamptz
) to authenticated;

create or replace function public.complete_room_inspection(
  p_inspection_id uuid,
  p_expected_updated_at timestamptz,
  p_summary text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inspection public.room_inspections%rowtype;
  v_summary text := trim(coalesce(p_summary, ''));
begin
  if auth.uid() is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may complete room inspections'
      using errcode = '42501';
  end if;

  if char_length(v_summary) < 5 or char_length(v_summary) > 4000 then
    raise exception 'Inspection summary must be between 5 and 4000 characters';
  end if;

  select *
    into v_inspection
  from public.room_inspections
  where id = p_inspection_id
  for update;

  if not found then
    raise exception 'Inspection not found';
  end if;

  if p_expected_updated_at is null
     or v_inspection.updated_at is distinct from p_expected_updated_at then
    raise exception 'This inspection changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_inspection.status <> 'in_progress' then
    raise exception 'Only inspections in progress can be completed';
  end if;

  update public.room_inspections
  set
    status = 'completed',
    summary = v_summary,
    completed_at = now()
  where id = p_inspection_id;
end;
$$;

revoke all on function public.complete_room_inspection(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.complete_room_inspection(
  uuid, timestamptz, text
) to authenticated;

create or replace function public.cancel_room_inspection(
  p_inspection_id uuid,
  p_expected_updated_at timestamptz,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inspection public.room_inspections%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if auth.uid() is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may cancel room inspections'
      using errcode = '42501';
  end if;

  if char_length(v_reason) < 5 or char_length(v_reason) > 1000 then
    raise exception 'Cancellation reason must be between 5 and 1000 characters';
  end if;

  select *
    into v_inspection
  from public.room_inspections
  where id = p_inspection_id
  for update;

  if not found then
    raise exception 'Inspection not found';
  end if;

  if p_expected_updated_at is null
     or v_inspection.updated_at is distinct from p_expected_updated_at then
    raise exception 'This inspection changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_inspection.status not in ('scheduled', 'in_progress') then
    raise exception 'Only active inspections can be cancelled';
  end if;

  update public.room_inspections
  set
    status = 'cancelled',
    cancelled_at = now(),
    cancellation_reason = v_reason
  where id = p_inspection_id;
end;
$$;

revoke all on function public.cancel_room_inspection(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.cancel_room_inspection(
  uuid, timestamptz, text
) to authenticated;

create or replace function public.register_room_inspection_evidence(
  p_inspection_id uuid,
  p_finding_id uuid,
  p_storage_path text,
  p_original_name text,
  p_content_type text,
  p_size_bytes bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_evidence_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may attach inspection evidence'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.room_inspections
    where id = p_inspection_id
  ) then
    raise exception 'Inspection not found';
  end if;

  if p_finding_id is not null
     and not exists (
       select 1
       from public.room_inspection_findings
       where id = p_finding_id
         and inspection_id = p_inspection_id
     ) then
    raise exception 'Finding does not belong to this inspection';
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

  insert into public.room_inspection_evidence (
    inspection_id,
    finding_id,
    storage_path,
    original_name,
    content_type,
    size_bytes,
    uploaded_by
  )
  values (
    p_inspection_id,
    p_finding_id,
    p_storage_path,
    p_original_name,
    p_content_type,
    p_size_bytes,
    v_actor
  )
  returning id into v_evidence_id;

  return v_evidence_id;
end;
$$;

revoke all on function public.register_room_inspection_evidence(
  uuid, uuid, text, text, text, bigint
) from public, anon;
grant execute on function public.register_room_inspection_evidence(
  uuid, uuid, text, text, text, bigint
) to authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'room_inspections',
    'room_inspection_findings',
    'room_inspection_evidence'
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
