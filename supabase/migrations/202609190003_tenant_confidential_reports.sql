-- Tenant-only confidential concern submission and history.
-- Staff review policies/functions are intentionally deferred to a later phase.

create table if not exists public.confidential_reports (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  category text not null check (
    category in ('safety_concern', 'rule_violation', 'roommate_concern', 'other')
  ),
  summary text not null check (char_length(btrim(summary)) between 10 and 4000),
  status text not null default 'submitted' check (
    status in ('submitted', 'under_review', 'resolved', 'dismissed')
  ),
  response_notes text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists confidential_reports_tenant_created_idx
  on public.confidential_reports(tenant_id, created_at desc);

alter table public.confidential_reports enable row level security;

revoke all on table public.confidential_reports from anon;
grant select, insert on table public.confidential_reports to authenticated;

drop policy if exists "tenants create own confidential reports"
  on public.confidential_reports;
create policy "tenants create own confidential reports"
  on public.confidential_reports for insert to authenticated
  with check (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
    and status = 'submitted'
    and response_notes is null
    and reviewed_by is null
    and reviewed_at is null
  );

drop policy if exists "tenants read own confidential reports"
  on public.confidential_reports;
create policy "tenants read own confidential reports"
  on public.confidential_reports for select to authenticated
  using (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
  );

-- Tenants deliberately receive no UPDATE or DELETE policy. Once submitted,
-- evidence cannot be silently altered or withdrawn from the audit trail.

create or replace function public.set_confidential_report_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists confidential_reports_updated_at
  on public.confidential_reports;
create trigger confidential_reports_updated_at
  before update on public.confidential_reports
  for each row execute function public.set_confidential_report_updated_at();

comment on table public.confidential_reports is
  'Restricted tenant safety concerns. Tenant-only access in phase one; staff review is deferred.';
