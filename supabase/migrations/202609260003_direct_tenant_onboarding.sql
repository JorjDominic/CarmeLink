-- Migration: Allow direct tenant onboarding submission without requiring a QR code.
-- Enables tenants to submit and update their academic and emergency contact
-- details directly from the CarmeLink app upon login.

-- 1. RPC: submit_tenant_onboarding_details
-- Called by the tenant in-app to submit or update their onboarding details.
create or replace function public.submit_tenant_onboarding_details(
  p_school_name                    text    default '',
  p_course_or_program              text    default '',
  p_year_level                     smallint default null,
  p_emergency_contact_name         text    default '',
  p_emergency_contact_phone        text    default '',
  p_emergency_contact_relationship text    default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select public.current_user_role()) <> 'tenant' then
    raise exception 'Only tenants can update their onboarding details';
  end if;

  update public.tenant_details
  set
    school_name                    = coalesce(nullif(trim(p_school_name), ''), school_name),
    course_or_program              = coalesce(nullif(trim(p_course_or_program), ''), course_or_program),
    year_level                     = coalesce(p_year_level, year_level),
    emergency_contact_name         = coalesce(nullif(trim(p_emergency_contact_name), ''), emergency_contact_name),
    emergency_contact_phone        = coalesce(nullif(trim(p_emergency_contact_phone), ''), emergency_contact_phone),
    emergency_contact_relationship = coalesce(nullif(trim(p_emergency_contact_relationship), ''), emergency_contact_relationship)
  where profile_id = auth.uid();

  if not found then
    -- Ensure tenant_details row exists
    insert into public.tenant_details (
      profile_id,
      school_name,
      course_or_program,
      year_level,
      emergency_contact_name,
      emergency_contact_phone,
      emergency_contact_relationship
    ) values (
      auth.uid(),
      nullif(trim(p_school_name), ''),
      nullif(trim(p_course_or_program), ''),
      p_year_level,
      nullif(trim(p_emergency_contact_name), ''),
      nullif(trim(p_emergency_contact_phone), ''),
      nullif(trim(p_emergency_contact_relationship), '')
    )
    on conflict (profile_id) do update set
      school_name                    = excluded.school_name,
      course_or_program              = excluded.course_or_program,
      year_level                     = excluded.year_level,
      emergency_contact_name         = excluded.emergency_contact_name,
      emergency_contact_phone        = excluded.emergency_contact_phone,
      emergency_contact_relationship = excluded.emergency_contact_relationship;
  end if;

  -- Mark any pending invitations for this tenant as completed
  update public.tenant_onboarding_invitations
  set status = 'completed', completed_at = now()
  where tenant_id = auth.uid() and status = 'pending';
end;
$$;

grant execute on function public.submit_tenant_onboarding_details(text, text, smallint, text, text, text) to authenticated;
revoke execute on function public.submit_tenant_onboarding_details(text, text, smallint, text, text, text) from anon;

-- 2. Add RLS policy allowing tenants to update their own tenant_details
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'tenant_details'
      and policyname = 'tenants update own details'
  ) then
    create policy "tenants update own details"
      on public.tenant_details for update to authenticated
      using (profile_id = auth.uid())
      with check (profile_id = auth.uid());
  end if;
end $$;
