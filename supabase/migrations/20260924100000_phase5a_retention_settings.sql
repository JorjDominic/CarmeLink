begin;

-- Phase 5A: Security & Retention Settings
--
-- Priority 17 requires administrative retention configuration only AFTER
-- client/legal/privacy review.
--
-- SAFETY BOUNDARY:
--   * stores proposed/reviewed retention settings
--   * records an audit trail
--   * exposes settings to authorized staff
--   * DOES NOT delete, purge, archive, anonymize, or schedule cleanup
--   * enforcement_enabled is database-constrained to FALSE in this phase
--
-- A later Leader-reviewed migration must explicitly change this contract before
-- any destructive or automated retention job can exist.

create table public.retention_policy_settings (
  record_key text primary key,
  display_name text not null
    check (char_length(trim(display_name)) between 3 and 120),
  description text not null
    check (char_length(trim(description)) between 10 and 1000),
  proposed_retention_days integer
    check (
      proposed_retention_days is null
      or proposed_retention_days > 0
    ),
  review_status text not null default 'draft'
    check (review_status in ('draft', 'pending_review', 'reviewed')),
  review_notes text not null default ''
    check (char_length(review_notes) <= 4000),
  enforcement_enabled boolean not null default false
    check (enforcement_enabled = false),
  updated_by uuid
    references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

create trigger retention_policy_settings_set_updated_at
before update on public.retention_policy_settings
for each row
execute function public.set_updated_at();

alter table public.retention_policy_settings enable row level security;

revoke all on public.retention_policy_settings from anon, authenticated;
grant select on public.retention_policy_settings to authenticated;

create policy "staff read retention policy settings"
on public.retention_policy_settings
for select
to authenticated
using ((select public.is_staff()));

create table public.retention_policy_events (
  id uuid primary key default gen_random_uuid(),
  record_key text not null
    references public.retention_policy_settings(record_key) on delete restrict,
  event_type text not null
    check (event_type in ('setting_updated')),
  actor_id uuid
    references public.profiles(id) on delete set null,
  actor_name text not null,
  previous_days integer,
  proposed_days integer,
  previous_review_status text,
  review_status text not null,
  notes text not null default ''
    check (char_length(notes) <= 4000),
  created_at timestamptz not null default now()
);

create index retention_policy_events_record_idx
  on public.retention_policy_events(record_key, created_at desc);

alter table public.retention_policy_events enable row level security;

revoke all on public.retention_policy_events from anon, authenticated;
grant select on public.retention_policy_events to authenticated;

create policy "staff read retention policy events"
on public.retention_policy_events
for select
to authenticated
using ((select public.is_staff()));

insert into public.retention_policy_settings (
  record_key,
  display_name,
  description
)
values
  (
    'geofence_and_gate_records',
    'Geofence & gate records',
    'Premises-status, gate-entry, and related curfew monitoring records that may contain sensitive location or presence information.'
  ),
  (
    'visitor_identity_media',
    'Visitor identity media',
    'Visitor identity images or related verification media retained for approved visitor-control workflows.'
  ),
  (
    'confidential_concern_records',
    'Confidential concern records',
    'Sensitive concern reports and administrative follow-up records with restricted reporter information.'
  ),
  (
    'conduct_case_evidence',
    'Conduct case evidence',
    'Restricted images and supporting records attached to conduct and disciplinary case review.'
  ),
  (
    'room_inspection_evidence',
    'Room inspection evidence',
    'Inspection photos and other evidence attached to room-condition findings and corrective-action review.'
  ),
  (
    'maintenance_photos',
    'Maintenance photos',
    'Tenant or staff-submitted maintenance images associated with repair and facilities records.'
  )
on conflict (record_key) do nothing;

create or replace function public.retention_policy_actor_name()
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
    'Authorized staff'
  );
$$;

revoke all on function public.retention_policy_actor_name()
  from public, anon, authenticated;
grant execute on function public.retention_policy_actor_name()
  to authenticated;

create or replace function public.update_retention_policy_setting(
  p_record_key text,
  p_proposed_retention_days integer,
  p_review_status text,
  p_review_notes text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_existing public.retention_policy_settings%rowtype;
  v_notes text := trim(coalesce(p_review_notes, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage retention settings'
      using errcode = '42501';
  end if;

  if p_review_status not in ('draft', 'pending_review', 'reviewed') then
    raise exception 'Invalid retention review status';
  end if;

  if p_proposed_retention_days is not null
     and p_proposed_retention_days <= 0 then
    raise exception 'Retention days must be greater than zero';
  end if;

  if char_length(v_notes) > 4000 then
    raise exception 'Retention review notes must be 4000 characters or fewer';
  end if;

  select *
    into v_existing
  from public.retention_policy_settings
  where record_key = p_record_key
  for update;

  if not found then
    raise exception 'Retention record group not found';
  end if;

  update public.retention_policy_settings
  set
    proposed_retention_days = p_proposed_retention_days,
    review_status = p_review_status,
    review_notes = v_notes,
    enforcement_enabled = false,
    updated_by = v_actor
  where record_key = p_record_key;

  insert into public.retention_policy_events (
    record_key,
    event_type,
    actor_id,
    actor_name,
    previous_days,
    proposed_days,
    previous_review_status,
    review_status,
    notes
  )
  values (
    p_record_key,
    'setting_updated',
    v_actor,
    public.retention_policy_actor_name(),
    v_existing.proposed_retention_days,
    p_proposed_retention_days,
    v_existing.review_status,
    p_review_status,
    v_notes
  );
end;
$$;

revoke all on function public.update_retention_policy_setting(
  text, integer, text, text
) from public, anon;
grant execute on function public.update_retention_policy_setting(
  text, integer, text, text
) to authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'retention_policy_settings',
    'retention_policy_events'
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
