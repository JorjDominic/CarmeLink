-- Create announcements table with audience targeting, pinning, and RLS policies.
-- Also includes notification dispatch metadata hooks ready for future FCM integration.

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 150),
  body text not null check (char_length(trim(body)) >= 2),
  category text not null default 'general'
    check (category in ('general', 'maintenance', 'utility', 'billing', 'emergency', 'event')),
  audience text not null default 'all'
    check (audience in ('all', 'tenants', 'guardians', 'staff')),
  is_pinned boolean not null default false,
  fcm_sent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for performance
create index if not exists announcements_created_at_idx
  on public.announcements (created_at desc);

create index if not exists announcements_is_pinned_idx
  on public.announcements (is_pinned desc, created_at desc);

create index if not exists announcements_audience_idx
  on public.announcements (audience);

create index if not exists announcements_author_id_idx
  on public.announcements (author_id);

-- Auto-update updated_at
drop trigger if exists announcements_set_updated_at on public.announcements;
create trigger announcements_set_updated_at
  before update on public.announcements
  for each row execute function public.set_updated_at();

-- Enable Row Level Security
alter table public.announcements enable row level security;

-- Policies: Staff (Owner & Caretaker) have full control
drop policy if exists "staff read all announcements" on public.announcements;
create policy "staff read all announcements"
  on public.announcements
  for select
  to authenticated
  using ((select public.is_staff()));

drop policy if exists "staff create announcements" on public.announcements;
create policy "staff create announcements"
  on public.announcements
  for insert
  to authenticated
  with check (
    (select public.is_staff())
    and author_id = (select auth.uid())
  );

drop policy if exists "staff update announcements" on public.announcements;
create policy "staff update announcements"
  on public.announcements
  for update
  to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

drop policy if exists "staff delete announcements" on public.announcements;
create policy "staff delete announcements"
  on public.announcements
  for delete
  to authenticated
  using ((select public.is_staff()));

-- Policies: Tenants can read announcements targeted to 'all' or 'tenants'
drop policy if exists "tenants read permitted announcements" on public.announcements;
create policy "tenants read permitted announcements"
  on public.announcements
  for select
  to authenticated
  using (
    (select public.current_user_role()) = 'tenant'
    and audience in ('all', 'tenants')
  );

-- Policies: Guardians can read announcements targeted to 'all' or 'guardians'
drop policy if exists "guardians read permitted announcements" on public.announcements;
create policy "guardians read permitted announcements"
  on public.announcements
  for select
  to authenticated
  using (
    (select public.current_user_role()) = 'guardian'
    and audience in ('all', 'guardians')
  );

-- Add to realtime publication if not already included
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'announcements'
  ) then
    alter publication supabase_realtime add table public.announcements;
  end if;
end $$;

-- Grants
revoke all on table public.announcements from anon;
grant select, insert, update, delete on table public.announcements to authenticated;

