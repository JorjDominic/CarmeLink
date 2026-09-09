create type public.app_role as enum (
  'tenant',
  'guardian',
  'owner_caretaker'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 1 and 120),
  role public.app_role not null,
  phone text not null default '',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- A signed-in user can read only their own server-controlled profile. There is
-- deliberately no client INSERT/UPDATE policy, so clients cannot choose roles.
create policy "users read their own profile"
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create or replace function public.current_user_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;

-- Use this pattern on every private feature table. Example for an owner-only
-- table: USING ((select public.current_user_role()) = 'owner_caretaker').
