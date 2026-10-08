-- READ ONLY: run manually in the SQL Editor of the same Supabase project as
-- the app (iuplkgvitovzjbmtzpme). These queries do not apply the migration.

-- 1. Registry and exact function signatures: NULL means the object is absent.
select to_regclass('public.room_floors') as floor_registry,
  to_regprocedure('public.create_room_floor(text)') as add_floor,
  to_regprocedure('public.manage_room_floor(text,text,integer,boolean)') as rename_merge_floor,
  to_regprocedure('public.safe_delete_room_floor(text)') as delete_floor,
  to_regprocedure('public.safe_delete_room(uuid)') as delete_room,
  to_regprocedure('public.rename_room_floor(text,text,integer)') as legacy_floor_rpc,
  to_regprocedure('public.guard_confidential_addendum_open_report()') as resolved_addenda_guard;

-- 2. Required baseline helpers/tables and identity/addenda columns.
select to_regprocedure('public.is_owner()') as owner_helper,
  to_regprocedure('public.is_staff()') as staff_helper,
  to_regprocedure('public.current_user_role()') as role_helper,
  to_regprocedure('public.create_room_with_four_beds(text,text,text)') as room_creation,
  to_regclass('public.confidential_report_addenda') as addenda,
  to_regclass('public.maintenance_reports') as maintenance;
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public' and
  ((table_name = 'rooms' and column_name in ('id','floor','capacity','is_active','layout_number','layout_floor'))
   or (table_name = 'confidential_report_addenda' and column_name = 'client_request_id')
   or (table_name = 'maintenance_reports' and column_name in ('room_id','location')))
order by table_name, column_name;

-- 3. Preflight data: both queries must return NO rows before migration.
-- Do not silently normalize/merge ambiguous existing floors.
select lower(btrim(floor)) as normalized, array_agg(distinct floor) as labels
from public.rooms group by lower(btrim(floor))
having count(distinct floor) > 1 or bool_or(floor <> btrim(floor))
  or bool_or(char_length(floor) not between 1 and 60);
select r.id, r.room_number, r.capacity, count(b.id) as bed_count
from public.rooms r left join public.bed_spaces b on b.room_id = r.id
group by r.id, r.room_number, r.capacity having r.capacity <> 4 or count(b.id) <> 4;

-- 4. Record baseline counts before/after applying the reviewed migration.
select (select count(*) from public.rooms) as rooms,
  (select count(*) from public.bed_spaces) as beds,
  (select count(*) from public.tenant_assignments) as assignments,
  (select count(*) from public.tenant_assignments where status = 'active') as active_assignments;

-- 5. Review actual dependency FKs and structural guards. Do not apply if the
-- expected baseline bed_spaces_room_id_fkey or structural triggers are absent.
select conrelid::regclass as referencing_table, conname,
  pg_get_constraintdef(oid) as definition
from pg_constraint where contype = 'f' and
  (confrelid in (to_regclass('public.rooms'), to_regclass('public.bed_spaces'), to_regclass('public.room_floors'))
   or conname = 'rooms_floor_registry_fkey') order by conrelid::regclass::text, conname;
select tgrelid::regclass as table_name, tgname, tgenabled, pg_get_triggerdef(oid) as definition
from pg_trigger where not tgisinternal and tgrelid in
  (to_regclass('public.rooms'), to_regclass('public.bed_spaces'), to_regclass('public.confidential_report_addenda'));

-- 6. Postflight grants/RLS. Authenticated SELECT must be true; staff-only read
-- policy must exist. Direct writes to registry intentionally remain denied.
select c.relname, c.relrowsecurity,
  has_table_privilege('authenticated', c.oid, 'SELECT') as authenticated_select,
  has_table_privilege('authenticated', c.oid, 'INSERT') as direct_insert
from pg_class c where c.oid = to_regclass('public.room_floors');
select policyname, roles, cmd, qual, with_check from pg_policies
where schemaname = 'public' and tablename = 'room_floors';
select p.oid::regprocedure as signature, p.prosecdef as security_definer,
  p.proconfig as function_settings,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in
  ('create_room_floor','manage_room_floor','safe_delete_room_floor','safe_delete_room');
select schemaname, tablename from pg_publication_tables
where pubname = 'supabase_realtime' and tablename in ('rooms','room_floors');
