-- READ ONLY. Same configured Supabase project; run manually as admin.
-- Do NOT run reminder/push RPCs to test availability: those send real alerts.
-- Also run phase3_floor_management_preflight.sql for floor FKs and baseline counts.
select now(), current_setting('TimeZone') as database_timezone,
  to_regclass('cron.job') as cron_jobs,
  to_regclass('supabase_migrations.schema_migrations') as migration_history;

select required, to_regclass('public.' || required) as installed
from unnest(array['curfew_requests','curfew_return_reminder_log',
  'app_notifications','push_device_tokens','guardian_alert_cron_credentials',
  'confidential_reports','confidential_report_addenda','confidential_report_audit',
  'conduct_cases','conduct_case_events','conduct_case_appeals',
  'rooms','bed_spaces','tenant_assignments','maintenance_reports',
  'room_inspections','room_inspection_findings','room_inspection_evidence',
  'room_cleaning_assignments','room_floors']) as required;

-- NULL signature is a missing dependency, not a reason to bypass permissions.
select signature, to_regprocedure(signature) as installed
from unnest(array[
 'public.submit_curfew_request(text,text,timestamp with time zone,timestamp with time zone,text)',
 'public.process_curfew_return_reminders()',
 'private.process_nightly_curfew_status()',
 'public.mark_notification_read(uuid)', 'public.mark_all_notifications_read()',
 'public.my_unread_notification_count()', 'public.cleanup_my_expired_notifications()',
 'public.claim_report_push_jobs()', 'private.dispatch_report_pushes()',
 'public.owner_review_confidential_report(uuid,text,text)',
 'public.list_confidential_reports_v2()',
 'public.append_confidential_report_addendum(uuid,text,text)'
]) as signature;

-- Inspect exact deployed signatures/settings/grants without executing functions.
select n.nspname, p.oid::regprocedure as signature, p.prosecdef,
 p.proconfig, has_function_privilege('authenticated',p.oid,'EXECUTE') as app_execute,
 has_function_privilege('anon',p.oid,'EXECUTE') as anonymous_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') and
 (p.proname in ('emit_app_notification','emit_staff_notification',
 'emit_tenant_circle_notification','mark_notification_read','mark_all_notifications_read',
 'my_unread_notification_count','cleanup_my_expired_notifications',
 'process_curfew_return_reminders','process_nightly_curfew_status',
 'claim_report_push_jobs','dispatch_report_pushes','submit_curfew_request',
 'owner_review_confidential_report','list_confidential_reports_v2',
 'append_confidential_report_addendum','create_conduct_case','publish_conduct_case',
 'issue_conduct_case_warning','set_conduct_case_review_status',
 'submit_conduct_case_response','recommend_conduct_termination_review'))
order by n.nspname,p.proname;

select table_name,column_name,data_type from information_schema.columns
where table_schema='public' and table_name in
 ('curfew_requests','app_notifications','confidential_report_addenda')
order by table_name,ordinal_position;

select c.relname,c.relrowsecurity,
 has_table_privilege('anon',c.oid,'SELECT') as anon_select,
 has_table_privilege('authenticated',c.oid,'SELECT') as app_select
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in
 ('curfew_requests','app_notifications','push_device_tokens',
 'confidential_reports','confidential_report_addenda','conduct_cases',
 'rooms','bed_spaces','tenant_assignments','room_floors');
select tablename,policyname,roles,cmd,qual,with_check from pg_policies
where schemaname='public' and tablename in
 ('curfew_requests','app_notifications','push_device_tokens',
 'confidential_reports','confidential_report_addenda','conduct_cases',
 'rooms','bed_spaces','tenant_assignments','room_floors');
select tgrelid::regclass as table_name,tgname,tgenabled,pg_get_triggerdef(oid)
from pg_trigger where not tgisinternal and tgrelid in
 (select c.oid from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relname in
 ('curfew_requests','app_notifications','confidential_reports',
 'confidential_report_addenda','conduct_case_events','conduct_case_appeals',
 'maintenance_reports','room_inspections','room_inspection_findings',
 'room_inspection_evidence','room_cleaning_assignments','rooms','bed_spaces'));
select schemaname,tablename from pg_publication_tables
where pubname='supabase_realtime' and tablename in
 ('app_notifications','curfew_requests','rooms','bed_spaces',
 'tenant_assignments','room_floors','confidential_reports','conduct_cases');

-- Run separately ONLY if the first query confirms these catalogs exist.
-- No commands, bearer values, tokens, private notification bodies or tenant rows.
select version from supabase_migrations.schema_migrations
where version in ('202610070005','202610070012','202610080007',
 '202610080008','202610090001','202610090002') order by version;
select jobid,jobname,schedule,active from cron.job
where jobname in ('curfew-return-reminders','nightly-curfew-status','report-push-delivery');
select j.jobname,d.status,count(*) as runs,max(d.end_time) as latest_end
from cron.job j join cron.job_run_details d on d.jobid=j.jobid
where j.jobname in ('curfew-return-reminders','nightly-curfew-status','report-push-delivery')
 and d.start_time>now()-interval '24 hours'
group by j.jobname,d.status;
