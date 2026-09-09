create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role in ('owner', 'caretaker')
     from public.profiles
     where id = (select auth.uid())),
    false
  );
$$;

create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'owner'
     from public.profiles
     where id = (select auth.uid())),
    false
  );
$$;

revoke all on function public.is_staff() from public, anon;
revoke all on function public.is_owner() from public, anon;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_owner() to authenticated;

comment on function public.is_staff() is
  'True for owner and caretaker accounts; use for operational permissions.';
comment on function public.is_owner() is
  'True only for owners; use for finance, analytics, roles, and account administration.';
