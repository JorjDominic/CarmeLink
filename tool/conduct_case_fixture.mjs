// Real conduct migrations with isolated identities and Storage metadata.
import {readFileSync} from 'node:fs';
const source=name=>readFileSync(`supabase/migrations/${name}`,'utf8');
export async function bootstrapConductFixture(db,ids) {
  await db.exec(`
    do $$ begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if; if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if; end $$;
    create schema auth; create schema storage;
    grant usage on schema auth,public to authenticated,anon;
    create function auth.uid() returns uuid language sql as $$ select nullif(current_setting('test.actor',true),'')::uuid $$;
    create table profiles(id uuid primary key,role text,full_name text);
    create function current_user_role() returns text language sql security definer set search_path='' as $$ select role from public.profiles where id=auth.uid() $$;
    create function is_staff() returns boolean language sql security definer set search_path='' as $$ select coalesce(public.current_user_role() in ('owner','caretaker'),false) $$;
    create function set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=clock_timestamp(); return new; end $$;
    create publication supabase_realtime;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,metadata jsonb,owner_id text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant usage on schema storage to authenticated;
    grant select,insert,update,delete on storage.objects to authenticated;
    create table maintenance_reports(id uuid primary key default gen_random_uuid(),tenant_id uuid references profiles,
      status text default 'pending',updated_at timestamptz default now());
    alter table maintenance_reports enable row level security;
    grant select on maintenance_reports to authenticated;
    create policy "staff read maintenance" on maintenance_reports for select to authenticated using (is_staff());
    create policy "staff update maintenance reports" on maintenance_reports for update to authenticated using (is_staff());
    create trigger maintenance_updated before update on maintenance_reports for each row execute function set_updated_at();
    create table app_notifications(id uuid primary key default gen_random_uuid(),recipient_id uuid,
      notification_type text,title text,body text,route_type text,route_id uuid,data jsonb,created_at timestamptz default now());
    create table notification_push_jobs(notification_id uuid primary key);
  `);
  for (const [role,id] of Object.entries(ids)) await db.query('insert into profiles values($1,$2,$3)',[id,role==='other'?'tenant':role==='missing'?null:role,role]);
  await db.exec(source('202609100001_staff_maintenance_workflow.sql'));
  await db.exec(source('202609190003_tenant_confidential_reports.sql'));
  await db.exec(source('202609190004_owner_confidential_report_review.sql'));
  await db.exec(source('20260924070000_phase4a_conduct_cases.sql'));
  await db.exec(source('20260924090000_phase4c_conduct_case_appeals.sql'));
  const helpers=source('202610070012_notification_coverage_completion.sql');
  await db.exec(helpers.slice(helpers.indexOf('create or replace function public.emit_app_notification('),helpers.indexOf('-- Contract/onboarding milestones')));
  const queue=source('202610070005_report_push_delivery.sql');
  await db.exec(queue.slice(queue.indexOf('create or replace function public.queue_server_report_push()'),queue.indexOf('create or replace function public.claim_report_push_jobs()')));
  const saved=source('202610090001_phase2_saved_report_notifications.sql');
  await db.exec(saved.slice(saved.indexOf('create or replace function public.notify_conduct_report_saved_event()'),saved.indexOf('create or replace function public.notify_conduct_appeal_saved_changes()')));
  await db.exec(source('202610140001_phase5_report_and_conduct_responses.sql'));

}
