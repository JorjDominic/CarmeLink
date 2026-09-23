begin;

create table public.employee_curfew_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  allowed_return_time time without time zone not null,
  weekdays smallint[] not null,
  effective_from date not null,
  effective_until date,
  work_schedule_note text not null
    check (char_length(trim(work_schedule_note)) between 5 and 2000),
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'revoked')),
  approval_note text not null default ''
    check (char_length(approval_note) <= 2000),
  approved_by uuid references public.profiles(id) on delete restrict,
  approved_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete restrict,
  revoked_at timestamptz,
  revocation_reason text not null default ''
    check (char_length(revocation_reason) <= 2000),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    array_length(weekdays, 1) is not null
    and weekdays <@ array[1,2,3,4,5,6,7]::smallint[]
  ),
  check (effective_until is null or effective_until >= effective_from),
  check (
    (status = 'approved' and approved_by is not null and approved_at is not null)
    or status <> 'approved'
  ),
  check (
    (status = 'revoked' and revoked_by is not null and revoked_at is not null)
    or status <> 'revoked'
  )
);

create index employee_curfew_profiles_tenant_idx
  on public.employee_curfew_profiles(tenant_id, created_at desc);

create index employee_curfew_profiles_effective_idx
  on public.employee_curfew_profiles(
    tenant_id, status, effective_from, effective_until
  );

create trigger employee_curfew_profiles_set_updated_at
before update on public.employee_curfew_profiles
for each row execute function public.set_updated_at();

alter table public.employee_curfew_profiles enable row level security;
revoke all on public.employee_curfew_profiles from anon, authenticated;
grant select on public.employee_curfew_profiles to authenticated;

create policy "staff read employee curfew profiles"
on public.employee_curfew_profiles
for select to authenticated
using ((select public.is_staff()));

create policy "tenant read own approved employee curfew profiles"
on public.employee_curfew_profiles
for select to authenticated
using (
  tenant_id = (select auth.uid())
  and status = 'approved'
);

create table public.employee_curfew_profile_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null
    references public.employee_curfew_profiles(id) on delete cascade,
  event_type text not null
    check (event_type in ('created', 'updated', 'approved', 'revoked')),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_name text not null,
  notes text not null default '' check (char_length(notes) <= 2000),
  created_at timestamptz not null default now()
);

create index employee_curfew_profile_events_profile_idx
  on public.employee_curfew_profile_events(profile_id, created_at);

alter table public.employee_curfew_profile_events enable row level security;
revoke all on public.employee_curfew_profile_events from anon, authenticated;
grant select on public.employee_curfew_profile_events to authenticated;

create policy "staff read employee curfew profile events"
on public.employee_curfew_profile_events
for select to authenticated
using ((select public.is_staff()));

create or replace function public.employee_curfew_actor_name()
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

revoke all on function public.employee_curfew_actor_name()
  from public, anon, authenticated;
grant execute on function public.employee_curfew_actor_name()
  to authenticated;

create or replace function public.create_employee_curfew_profile(
  p_tenant_id uuid,
  p_allowed_return_time time without time zone,
  p_weekdays smallint[],
  p_effective_from date,
  p_effective_until date,
  p_work_schedule_note text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_note text := trim(coalesce(p_work_schedule_note, ''));
  v_profile_id uuid;
begin
  if v_actor is null or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage employee curfew profiles'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_tenant_id and role = 'tenant'
  ) then
    raise exception 'Selected tenant was not found';
  end if;

  if p_weekdays is null
     or array_length(p_weekdays, 1) is null
     or not (p_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'Select at least one valid weekday';
  end if;

  if p_effective_until is not null and p_effective_until < p_effective_from then
    raise exception 'Effective end date cannot be before the start date';
  end if;

  if char_length(v_note) < 5 or char_length(v_note) > 2000 then
    raise exception 'Work schedule note must be between 5 and 2000 characters';
  end if;

  insert into public.employee_curfew_profiles (
    tenant_id,
    allowed_return_time,
    weekdays,
    effective_from,
    effective_until,
    work_schedule_note,
    created_by
  )
  values (
    p_tenant_id,
    p_allowed_return_time,
    (
      select array_agg(distinct value order by value)::smallint[]
      from unnest(p_weekdays) as value
    ),
    p_effective_from,
    p_effective_until,
    v_note,
    v_actor
  )
  returning id into v_profile_id;

  insert into public.employee_curfew_profile_events (
    profile_id, event_type, actor_id, actor_name, notes
  )
  values (
    v_profile_id,
    'created',
    v_actor,
    public.employee_curfew_actor_name(),
    'Employee curfew profile created as draft.'
  );

  return v_profile_id;
end;
$$;

revoke all on function public.create_employee_curfew_profile(
  uuid, time without time zone, smallint[], date, date, text
) from public, anon;
grant execute on function public.create_employee_curfew_profile(
  uuid, time without time zone, smallint[], date, date, text
) to authenticated;

create or replace function public.update_employee_curfew_profile(
  p_profile_id uuid,
  p_expected_updated_at timestamptz,
  p_allowed_return_time time without time zone,
  p_weekdays smallint[],
  p_effective_from date,
  p_effective_until date,
  p_work_schedule_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.employee_curfew_profiles%rowtype;
  v_note text := trim(coalesce(p_work_schedule_note, ''));
begin
  if v_actor is null or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage employee curfew profiles'
      using errcode = '42501';
  end if;

  select * into v_profile
  from public.employee_curfew_profiles
  where id = p_profile_id
  for update;

  if not found then
    raise exception 'Employee curfew profile not found';
  end if;

  if p_expected_updated_at is null
     or v_profile.updated_at is distinct from p_expected_updated_at then
    raise exception 'This employee curfew profile changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_profile.status <> 'draft' then
    raise exception 'Only draft employee curfew profiles can be edited';
  end if;

  if p_weekdays is null
     or array_length(p_weekdays, 1) is null
     or not (p_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'Select at least one valid weekday';
  end if;

  if p_effective_until is not null and p_effective_until < p_effective_from then
    raise exception 'Effective end date cannot be before the start date';
  end if;

  if char_length(v_note) < 5 or char_length(v_note) > 2000 then
    raise exception 'Work schedule note must be between 5 and 2000 characters';
  end if;

  update public.employee_curfew_profiles
  set
    allowed_return_time = p_allowed_return_time,
    weekdays = (
      select array_agg(distinct value order by value)::smallint[]
      from unnest(p_weekdays) as value
    ),
    effective_from = p_effective_from,
    effective_until = p_effective_until,
    work_schedule_note = v_note
  where id = p_profile_id;

  insert into public.employee_curfew_profile_events (
    profile_id, event_type, actor_id, actor_name, notes
  )
  values (
    p_profile_id,
    'updated',
    v_actor,
    public.employee_curfew_actor_name(),
    'Draft employee curfew profile updated.'
  );
end;
$$;

revoke all on function public.update_employee_curfew_profile(
  uuid, timestamptz, time without time zone, smallint[], date, date, text
) from public, anon;
grant execute on function public.update_employee_curfew_profile(
  uuid, timestamptz, time without time zone, smallint[], date, date, text
) to authenticated;

create or replace function public.approve_employee_curfew_profile(
  p_profile_id uuid,
  p_expected_updated_at timestamptz,
  p_approval_note text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.employee_curfew_profiles%rowtype;
  v_note text := trim(coalesce(p_approval_note, ''));
begin
  if v_actor is null or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may approve employee curfew profiles'
      using errcode = '42501';
  end if;

  select * into v_profile
  from public.employee_curfew_profiles
  where id = p_profile_id
  for update;

  if not found then
    raise exception 'Employee curfew profile not found';
  end if;

  if p_expected_updated_at is null
     or v_profile.updated_at is distinct from p_expected_updated_at then
    raise exception 'This employee curfew profile changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_profile.status <> 'draft' then
    raise exception 'Only draft employee curfew profiles can be approved';
  end if;

  if v_profile.effective_until is not null
     and v_profile.effective_until < current_date then
    raise exception 'An already-ended employee curfew profile cannot be approved';
  end if;

  if char_length(v_note) > 2000 then
    raise exception 'Approval note must be 2000 characters or fewer';
  end if;

  if exists (
    select 1
    from public.employee_curfew_profiles existing
    where existing.tenant_id = v_profile.tenant_id
      and existing.id <> v_profile.id
      and existing.status = 'approved'
      and daterange(
            existing.effective_from,
            coalesce(existing.effective_until, 'infinity'::date),
            '[]'
          )
          &&
          daterange(
            v_profile.effective_from,
            coalesce(v_profile.effective_until, 'infinity'::date),
            '[]'
          )
  ) then
    raise exception 'This tenant already has an overlapping approved employee curfew profile';
  end if;

  update public.employee_curfew_profiles
  set
    status = 'approved',
    approval_note = v_note,
    approved_by = v_actor,
    approved_at = now(),
    revoked_by = null,
    revoked_at = null,
    revocation_reason = ''
  where id = p_profile_id;

  insert into public.employee_curfew_profile_events (
    profile_id, event_type, actor_id, actor_name, notes
  )
  values (
    p_profile_id,
    'approved',
    v_actor,
    public.employee_curfew_actor_name(),
    case when v_note = ''
      then 'Employee curfew profile approved.'
      else v_note
    end
  );
end;
$$;

revoke all on function public.approve_employee_curfew_profile(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.approve_employee_curfew_profile(
  uuid, timestamptz, text
) to authenticated;

create or replace function public.revoke_employee_curfew_profile(
  p_profile_id uuid,
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
  v_profile public.employee_curfew_profiles%rowtype;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if v_actor is null or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may revoke employee curfew profiles'
      using errcode = '42501';
  end if;

  select * into v_profile
  from public.employee_curfew_profiles
  where id = p_profile_id
  for update;

  if not found then
    raise exception 'Employee curfew profile not found';
  end if;

  if p_expected_updated_at is null
     or v_profile.updated_at is distinct from p_expected_updated_at then
    raise exception 'This employee curfew profile changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_profile.status <> 'approved' then
    raise exception 'Only approved employee curfew profiles can be revoked';
  end if;

  if char_length(v_reason) < 5 or char_length(v_reason) > 2000 then
    raise exception 'Revocation reason must be between 5 and 2000 characters';
  end if;

  update public.employee_curfew_profiles
  set
    status = 'revoked',
    revoked_by = v_actor,
    revoked_at = now(),
    revocation_reason = v_reason
  where id = p_profile_id;

  insert into public.employee_curfew_profile_events (
    profile_id, event_type, actor_id, actor_name, notes
  )
  values (
    p_profile_id,
    'revoked',
    v_actor,
    public.employee_curfew_actor_name(),
    v_reason
  );
end;
$$;

revoke all on function public.revoke_employee_curfew_profile(
  uuid, timestamptz, text
) from public, anon;
grant execute on function public.revoke_employee_curfew_profile(
  uuid, timestamptz, text
) to authenticated;

-- Read-only handoff for later Leader-reviewed evaluator integration.
create or replace function public.resolve_employee_curfew_profile(
  p_tenant_id uuid,
  p_at timestamptz default now()
)
returns table (
  profile_id uuid,
  allowed_return_time time without time zone,
  effective_from date,
  effective_until date,
  weekdays smallint[],
  work_schedule_note text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_local_date date;
  v_local_weekday smallint;
begin
  if v_actor is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select role::text into v_role
  from public.profiles
  where id = v_actor;

  if not coalesce(public.is_staff(), false)
     and not (v_role = 'tenant' and v_actor = p_tenant_id) then
    raise exception 'Employee curfew profile is not available to your account'
      using errcode = '42501';
  end if;

  v_local_date := (p_at at time zone 'Asia/Manila')::date;
  v_local_weekday :=
    extract(isodow from (p_at at time zone 'Asia/Manila'))::smallint;

  return query
  select
    profile.id,
    profile.allowed_return_time,
    profile.effective_from,
    profile.effective_until,
    profile.weekdays,
    profile.work_schedule_note
  from public.employee_curfew_profiles profile
  where profile.tenant_id = p_tenant_id
    and profile.status = 'approved'
    and profile.effective_from <= v_local_date
    and (
      profile.effective_until is null
      or profile.effective_until >= v_local_date
    )
    and v_local_weekday = any(profile.weekdays)
  order by profile.effective_from desc, profile.approved_at desc
  limit 1;
end;
$$;

revoke all on function public.resolve_employee_curfew_profile(
  uuid, timestamptz
) from public, anon;
grant execute on function public.resolve_employee_curfew_profile(
  uuid, timestamptz
) to authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'employee_curfew_profiles',
    'employee_curfew_profile_events'
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
