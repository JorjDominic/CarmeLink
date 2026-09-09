-- Anonymous clients receive no access to private application tables.
revoke all on table public.profiles from anon;
revoke all on table public.rooms from anon;
revoke all on table public.bed_spaces from anon;
revoke all on table public.guardian_tenant_links from anon;
revoke all on table public.tenant_assignments from anon;

-- Profiles are server-managed. Authenticated clients can only select rows
-- allowed by profile RLS and cannot assign or modify roles.
revoke all on table public.profiles from authenticated;
grant select on table public.profiles to authenticated;

-- Authenticated API operations remain subject to the RLS policies created in
-- the core-structure migration. Only staff policies permit writes.
revoke all on table public.rooms from authenticated;
revoke all on table public.bed_spaces from authenticated;
revoke all on table public.guardian_tenant_links from authenticated;
revoke all on table public.tenant_assignments from authenticated;
grant select, insert, update, delete on table public.rooms to authenticated;
grant select, insert, update, delete on table public.bed_spaces to authenticated;
grant select, insert, update, delete on table public.guardian_tenant_links to authenticated;
grant select, insert, update, delete on table public.tenant_assignments to authenticated;

-- Trigger functions are internal and cannot be invoked as public RPCs.
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.validate_bed_space_capacity() from public, anon, authenticated;
revoke all on function public.validate_room_capacity() from public, anon, authenticated;
revoke all on function public.validate_bed_space_status() from public, anon, authenticated;
revoke all on function public.validate_dormitory_relationships() from public, anon, authenticated;

-- These narrowly scoped helpers are required by RLS policies.
revoke all on function public.current_user_role() from public, anon;
revoke all on function public.is_staff() from public, anon;
revoke all on function public.is_guardian_of(uuid) from public, anon;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_guardian_of(uuid) to authenticated;
