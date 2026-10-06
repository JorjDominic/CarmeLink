-- Phase 3 database contract smoke checks.
-- Run against a migrated test database.

select to_regprocedure(
  'public.reschedule_visitor_request(uuid,timestamptz,timestamptz,timestamptz,text,boolean)'
) is not null as has_reschedule_rpc;

select to_regprocedure('public.process_visitor_reminders()') is not null
  as has_visitor_reminder_processor;

select exists (
  select 1
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'visitor_events'
    and column_name = 'details'
) as visitor_events_have_details;

select exists (
  select 1
  from pg_publication_tables
  where pubname = 'supabase_realtime'
    and schemaname = 'public'
    and tablename = 'dormitory_options'
) as dormitory_options_are_realtime;
