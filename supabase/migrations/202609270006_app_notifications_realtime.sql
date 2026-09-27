-- Keep in-app notification lists and unread badges live across web and mobile.
-- RLS on app_notifications remains authoritative; this only exposes row changes
-- through Supabase Realtime to users who can already select those rows.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'app_notifications'
  ) then
    execute 'alter publication supabase_realtime add table public.app_notifications';
  end if;
end;
$$;
