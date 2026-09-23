begin;

-- Phase 4C: Conduct Case Appeals
--
-- Source-grounded scope:
--   * tenant may contest a disciplinary decision
--   * tenant may submit supporting information
--   * authorized staff reviews the appeal
--
-- This phase deliberately does NOT:
--   * reopen or rewrite the conduct case automatically
--   * reverse a warning automatically
--   * mutate termination/eviction workflow
--   * create or reverse any financial charge
--   * change curfew-request / guardian-approval state
--
-- An accepted appeal is recorded as an administrative decision. Any resulting
-- change to a shared case/lifecycle state remains a separate reviewed action.

create table public.conduct_case_appeals (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null
    references public.conduct_cases(id) on delete cascade,
  tenant_id uuid not null
    references public.profiles(id) on delete restrict,
  appeal_statement text not null
    check (char_length(trim(appeal_statement)) between 10 and 4000),
  supporting_information text not null default ''
    check (char_length(supporting_information) <= 4000),
  status text not null default 'submitted'
    check (
      status in (
        'submitted',
        'under_review',
        'accepted',
        'denied',
        'withdrawn'
      )
    ),
  reviewed_by uuid
    references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  decision_notes text not null default ''
    check (char_length(decision_notes) <= 4000),
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (
      status in ('accepted', 'denied')
      and reviewed_by is not null
      and reviewed_at is not null
      and char_length(trim(decision_notes)) >= 5
    )
    or status not in ('accepted', 'denied')
  )
);

create index conduct_case_appeals_case_idx
  on public.conduct_case_appeals(case_id, submitted_at desc);

create index conduct_case_appeals_tenant_idx
  on public.conduct_case_appeals(tenant_id, submitted_at desc);

create index conduct_case_appeals_status_idx
  on public.conduct_case_appeals(status, updated_at desc);

create unique index conduct_case_appeals_one_open_per_case
  on public.conduct_case_appeals(case_id)
  where status in ('submitted', 'under_review');

create trigger conduct_case_appeals_set_updated_at
before update on public.conduct_case_appeals
for each row
execute function public.set_updated_at();

alter table public.conduct_case_appeals enable row level security;

revoke all on public.conduct_case_appeals from anon, authenticated;
grant select on public.conduct_case_appeals to authenticated;

create policy "staff read conduct case appeals"
on public.conduct_case_appeals
for select
to authenticated
using ((select public.is_staff()));

create policy "tenant read own conduct case appeals"
on public.conduct_case_appeals
for select
to authenticated
using (tenant_id = (select auth.uid()));

create or replace function public.submit_conduct_case_appeal(
  p_case_id uuid,
  p_appeal_statement text,
  p_supporting_information text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case public.conduct_cases%rowtype;
  v_statement text := trim(coalesce(p_appeal_statement, ''));
  v_support text := trim(coalesce(p_supporting_information, ''));
  v_appeal_id uuid;
begin
  if v_actor is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select *
    into v_case
  from public.conduct_cases
  where id = p_case_id;

  if not found
     or v_case.tenant_id <> v_actor
     or v_case.tenant_notified_at is null then
    raise exception 'This conduct case is not available to your account'
      using errcode = '42501';
  end if;

  if v_case.status not in (
    'warning_issued',
    'resolved',
    'termination_review_recommended'
  ) then
    raise exception 'This conduct case is not currently eligible for an appeal';
  end if;

  if char_length(v_statement) < 10 or char_length(v_statement) > 4000 then
    raise exception 'Appeal statement must be between 10 and 4000 characters';
  end if;

  if char_length(v_support) > 4000 then
    raise exception 'Supporting information must be 4000 characters or fewer';
  end if;

  if exists (
    select 1
    from public.conduct_case_appeals
    where case_id = p_case_id
      and status in ('submitted', 'under_review')
  ) then
    raise exception 'This conduct case already has an appeal awaiting review';
  end if;

  insert into public.conduct_case_appeals (
    case_id,
    tenant_id,
    appeal_statement,
    supporting_information
  )
  values (
    p_case_id,
    v_actor,
    v_statement,
    v_support
  )
  returning id into v_appeal_id;

  return v_appeal_id;
end;
$$;

revoke all on function public.submit_conduct_case_appeal(
  uuid, text, text
) from public, anon;
grant execute on function public.submit_conduct_case_appeal(
  uuid, text, text
) to authenticated;

create or replace function public.withdraw_conduct_case_appeal(
  p_appeal_id uuid,
  p_expected_updated_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_appeal public.conduct_case_appeals%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication required'
      using errcode = '42501';
  end if;

  select *
    into v_appeal
  from public.conduct_case_appeals
  where id = p_appeal_id
  for update;

  if not found or v_appeal.tenant_id <> v_actor then
    raise exception 'This appeal is not available to your account'
      using errcode = '42501';
  end if;

  if p_expected_updated_at is null
     or v_appeal.updated_at is distinct from p_expected_updated_at then
    raise exception 'This appeal changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_appeal.status <> 'submitted' then
    raise exception 'Only a newly submitted appeal may be withdrawn';
  end if;

  update public.conduct_case_appeals
  set status = 'withdrawn'
  where id = p_appeal_id;
end;
$$;

revoke all on function public.withdraw_conduct_case_appeal(
  uuid, timestamptz
) from public, anon;
grant execute on function public.withdraw_conduct_case_appeal(
  uuid, timestamptz
) to authenticated;

create or replace function public.start_conduct_case_appeal_review(
  p_appeal_id uuid,
  p_expected_updated_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_appeal public.conduct_case_appeals%rowtype;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may review conduct case appeals'
      using errcode = '42501';
  end if;

  select *
    into v_appeal
  from public.conduct_case_appeals
  where id = p_appeal_id
  for update;

  if not found then
    raise exception 'Conduct case appeal not found';
  end if;

  if p_expected_updated_at is null
     or v_appeal.updated_at is distinct from p_expected_updated_at then
    raise exception 'This appeal changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_appeal.status <> 'submitted' then
    raise exception 'Only submitted appeals may move to review';
  end if;

  update public.conduct_case_appeals
  set status = 'under_review'
  where id = p_appeal_id;
end;
$$;

revoke all on function public.start_conduct_case_appeal_review(
  uuid, timestamptz
) from public, anon;
grant execute on function public.start_conduct_case_appeal_review(
  uuid, timestamptz
) to authenticated;

create or replace function public.decide_conduct_case_appeal(
  p_appeal_id uuid,
  p_expected_updated_at timestamptz,
  p_decision text,
  p_decision_notes text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_appeal public.conduct_case_appeals%rowtype;
  v_notes text := trim(coalesce(p_decision_notes, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may decide conduct case appeals'
      using errcode = '42501';
  end if;

  if p_decision not in ('accepted', 'denied') then
    raise exception 'Invalid appeal decision';
  end if;

  if char_length(v_notes) < 5 or char_length(v_notes) > 4000 then
    raise exception 'Decision notes must be between 5 and 4000 characters';
  end if;

  select *
    into v_appeal
  from public.conduct_case_appeals
  where id = p_appeal_id
  for update;

  if not found then
    raise exception 'Conduct case appeal not found';
  end if;

  if p_expected_updated_at is null
     or v_appeal.updated_at is distinct from p_expected_updated_at then
    raise exception 'This appeal changed. Refresh before continuing.'
      using errcode = '40001';
  end if;

  if v_appeal.status not in ('submitted', 'under_review') then
    raise exception 'This appeal is already closed';
  end if;

  update public.conduct_case_appeals
  set
    status = p_decision,
    reviewed_by = v_actor,
    reviewed_at = now(),
    decision_notes = v_notes
  where id = p_appeal_id;

  -- Intentionally no conduct_cases mutation here.
end;
$$;

revoke all on function public.decide_conduct_case_appeal(
  uuid, timestamptz, text, text
) from public, anon;
grant execute on function public.decide_conduct_case_appeal(
  uuid, timestamptz, text, text
) to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conduct_case_appeals'
  ) then
    alter publication supabase_realtime
      add table public.conduct_case_appeals;
  end if;
end $$;

commit;
