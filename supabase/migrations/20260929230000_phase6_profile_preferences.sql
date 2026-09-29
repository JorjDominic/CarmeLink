begin;

-- Phase 6: self-service profile editing and durable account appearance preferences.
--
-- Editable by the signed-in account:
--   * every role: full_name, phone
--   * tenant only: birth_date, address, school_name, course_or_program, year_level
--
-- Deliberately NOT editable here:
--   * email / authentication identity
--   * role / verification state
--   * tenant emergency-contact onboarding gates
--   * staff employee code, position, hired date, active state
--   * guardian/tenant links
--
-- The protected RPC is the authoritative write path for this profile editor.

create table if not exists public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  theme_mode text not null default 'light'
    check (theme_mode in ('system', 'light', 'dark')),
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;
revoke all on public.user_preferences from anon, authenticated;
grant select on public.user_preferences to authenticated;

drop policy if exists "users read own preferences" on public.user_preferences;
create policy "users read own preferences"
on public.user_preferences for select to authenticated
using (user_id = (select auth.uid()));

create table if not exists public.profile_change_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  changed_fields text[] not null check (cardinality(changed_fields) > 0),
  changed_at timestamptz not null default now()
);

create index if not exists profile_change_audit_user_changed_idx
  on public.profile_change_audit(user_id, changed_at desc);

alter table public.profile_change_audit enable row level security;
revoke all on public.profile_change_audit from anon, authenticated;

create or replace function public.get_my_user_preferences()
returns public.user_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.user_preferences;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  insert into public.user_preferences (user_id)
  values (v_actor)
  on conflict (user_id) do nothing;

  select * into v_row
  from public.user_preferences
  where user_id = v_actor;

  return v_row;
end;
$$;

create or replace function public.update_my_user_preferences(
  p_theme_mode text
)
returns public.user_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.user_preferences;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_theme_mode not in ('system', 'light', 'dark') then
    raise exception 'Invalid theme mode';
  end if;

  insert into public.user_preferences (user_id, theme_mode, updated_at)
  values (v_actor, p_theme_mode, now())
  on conflict (user_id) do update set
    theme_mode = excluded.theme_mode,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.get_my_editable_profile()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.app_role;
  v_profile public.profiles%rowtype;
  v_tenant public.tenant_details%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_actor;

  if not found then
    raise exception 'Profile not found';
  end if;

  v_role := v_profile.role;

  if v_role = 'tenant' then
    insert into public.tenant_details (profile_id)
    values (v_actor)
    on conflict (profile_id) do nothing;

    select * into v_tenant
    from public.tenant_details
    where profile_id = v_actor;
  end if;

  return jsonb_build_object(
    'id', v_profile.id,
    'role', v_profile.role::text,
    'full_name', v_profile.full_name,
    'phone', v_profile.phone,
    'birth_date', case when v_role = 'tenant' then v_tenant.birth_date else null end,
    'address', case when v_role = 'tenant' then v_tenant.address else null end,
    'school_name', case when v_role = 'tenant' then v_tenant.school_name else null end,
    'course_or_program', case when v_role = 'tenant' then v_tenant.course_or_program else null end,
    'year_level', case when v_role = 'tenant' then v_tenant.year_level else null end
  );
end;
$$;

create or replace function public.update_my_editable_profile(
  p_full_name text,
  p_phone text,
  p_birth_date date default null,
  p_address text default null,
  p_school_name text default null,
  p_course_or_program text default null,
  p_year_level smallint default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_tenant public.tenant_details%rowtype;
  v_name text := trim(coalesce(p_full_name, ''));
  v_phone text := trim(coalesce(p_phone, ''));
  v_changed text[] := array[]::text[];
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_actor
  for update;

  if not found then
    raise exception 'Profile not found';
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 120 then
    raise exception 'Full name must be between 2 and 120 characters';
  end if;

  if v_phone <> '' and (
    char_length(v_phone) < 7
    or char_length(v_phone) > 24
    or v_phone !~ '^[0-9+() .-]+$'
  ) then
    raise exception 'Enter a valid phone number';
  end if;

  if p_birth_date is not null and (
    p_birth_date > current_date
    or p_birth_date < (current_date - interval '120 years')::date
  ) then
    raise exception 'Enter a valid birth date';
  end if;

  if char_length(trim(coalesce(p_address, ''))) > 300 then
    raise exception 'Address must be 300 characters or fewer';
  end if;
  if char_length(trim(coalesce(p_school_name, ''))) > 160 then
    raise exception 'School name must be 160 characters or fewer';
  end if;
  if char_length(trim(coalesce(p_course_or_program, ''))) > 160 then
    raise exception 'Course or program must be 160 characters or fewer';
  end if;
  if p_year_level is not null and (p_year_level < 1 or p_year_level > 20) then
    raise exception 'Year level must be between 1 and 20';
  end if;

  if v_profile.full_name is distinct from v_name then
    v_changed := array_append(v_changed, 'full_name');
  end if;
  if v_profile.phone is distinct from v_phone then
    v_changed := array_append(v_changed, 'phone');
  end if;

  update public.profiles
  set full_name = v_name,
      phone = v_phone
  where id = v_actor;

  if v_profile.role = 'tenant' then
    insert into public.tenant_details (profile_id)
    values (v_actor)
    on conflict (profile_id) do nothing;

    select * into v_tenant
    from public.tenant_details
    where profile_id = v_actor
    for update;

    if v_tenant.birth_date is distinct from p_birth_date then
      v_changed := array_append(v_changed, 'birth_date');
    end if;
    if v_tenant.address is distinct from trim(coalesce(p_address, '')) then
      v_changed := array_append(v_changed, 'address');
    end if;
    if v_tenant.school_name is distinct from trim(coalesce(p_school_name, '')) then
      v_changed := array_append(v_changed, 'school_name');
    end if;
    if v_tenant.course_or_program is distinct from trim(coalesce(p_course_or_program, '')) then
      v_changed := array_append(v_changed, 'course_or_program');
    end if;
    if v_tenant.year_level is distinct from p_year_level then
      v_changed := array_append(v_changed, 'year_level');
    end if;

    update public.tenant_details
    set birth_date = p_birth_date,
        address = trim(coalesce(p_address, '')),
        school_name = trim(coalesce(p_school_name, '')),
        course_or_program = trim(coalesce(p_course_or_program, '')),
        year_level = p_year_level
    where profile_id = v_actor;
  elsif p_birth_date is not null
     or p_address is not null
     or p_school_name is not null
     or p_course_or_program is not null
     or p_year_level is not null then
    raise exception 'Tenant-only profile fields are not available for this role';
  end if;

  if cardinality(v_changed) > 0 then
    insert into public.profile_change_audit (
      user_id,
      actor_id,
      changed_fields
    ) values (
      v_actor,
      v_actor,
      v_changed
    );
  end if;

  return public.get_my_editable_profile();
end;
$$;

revoke all on function public.get_my_user_preferences() from public, anon;
grant execute on function public.get_my_user_preferences() to authenticated;

revoke all on function public.update_my_user_preferences(text) from public, anon;
grant execute on function public.update_my_user_preferences(text) to authenticated;

revoke all on function public.get_my_editable_profile() from public, anon;
grant execute on function public.get_my_editable_profile() to authenticated;

revoke all on function public.update_my_editable_profile(
  text, text, date, text, text, text, smallint
) from public, anon;
grant execute on function public.update_my_editable_profile(
  text, text, date, text, text, text, smallint
) to authenticated;

comment on function public.update_my_editable_profile(
  text, text, date, text, text, text, smallint
) is 'Self-service profile editor. Identity, role, verification, emergency-contact onboarding fields, guardian links, and staff employment fields remain outside this RPC.';

commit;
