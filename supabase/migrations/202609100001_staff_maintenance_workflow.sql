begin;

-- Requires both September 9 maintenance migrations.
alter table public.maintenance_reports
  add column staff_notes text not null default ''
    check (char_length(staff_notes) <= 2000),
  add column handled_by uuid
    references public.profiles(id) on delete set null,
  add column resolved_at timestamptz;

create table public.maintenance_staff_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null
    references public.maintenance_reports(id) on delete cascade,
  actor_id uuid
    references public.profiles(id) on delete set null,
  actor_name text not null,
  previous_status text not null,
  next_status text not null,
  notes text not null,
  created_at timestamptz not null default now()
);

create index maintenance_staff_history_report_idx
  on public.maintenance_staff_history(report_id, created_at desc);

alter table public.maintenance_staff_history
  enable row level security;

revoke all on public.maintenance_staff_history
  from anon, authenticated;

grant select on public.maintenance_staff_history
  to authenticated;

create policy "staff read maintenance history"
  on public.maintenance_staff_history
  for select
  to authenticated
  using ((select public.is_staff()));

-- Keep tenant CRUD, but protect staff-controlled fields.
create function public.protect_maintenance_staff_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.current_user_role() = 'tenant' then
    if TG_OP = 'INSERT' then
      if new.staff_notes <> ''
         or new.handled_by is not null
         or new.resolved_at is not null then
        raise exception 'Staff fields cannot be set by a tenant';
      end if;
    elsif new.staff_notes is distinct from old.staff_notes
       or new.handled_by is distinct from old.handled_by
       or new.resolved_at is distinct from old.resolved_at
       or new.id is distinct from old.id then
      raise exception
        'Staff fields and report ID cannot be changed by a tenant';
    end if;
  end if;

  return new;
end;
$$;

create trigger maintenance_reports_protect_staff_fields
before insert or update on public.maintenance_reports
for each row
execute function public.protect_maintenance_staff_fields();

revoke all on function public.protect_maintenance_staff_fields()
  from public, anon, authenticated;

-- Staff must use the protected function below.
drop policy "staff update maintenance reports"
  on public.maintenance_reports;

create function public.update_staff_maintenance(
  p_report_id uuid,
  p_expected_updated_at timestamptz,
  p_status text,
  p_notes text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report public.maintenance_reports%rowtype;
  v_actor uuid := auth.uid();
  v_name text;
  v_notes text := trim(coalesce(p_notes, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception
      'Only owners and caretakers may update maintenance'
      using errcode = '42501';
  end if;

  if p_status is null or p_status not in (
    'pending',
    'assigned',
    'in_progress',
    'resolved',
    'cancelled'
  ) then
    raise exception 'Invalid maintenance status';
  end if;

  if char_length(v_notes) > 2000 then
    raise exception 'Notes must be 2000 characters or fewer';
  end if;

  select *
    into v_report
    from public.maintenance_reports
    where id = p_report_id
    for update;

  if not found then
    raise exception
      'This report no longer exists. Refresh the queue.';
  end if;

  if p_expected_updated_at is null
     or v_report.updated_at is distinct from p_expected_updated_at then
    raise exception
      'This report changed. Reload it before saving.'
      using errcode = '40001';
  end if;

  if p_status <> v_report.status and not (
    (
      v_report.status = 'pending'
      and p_status in ('assigned', 'in_progress', 'cancelled')
    )
    or (
      v_report.status = 'assigned'
      and p_status in ('in_progress', 'cancelled')
    )
    or (
      v_report.status = 'in_progress'
      and p_status in ('resolved', 'cancelled')
    )
    or (
      v_report.status = 'resolved'
      and p_status = 'in_progress'
    )
  ) then
    raise exception 'That status transition is not allowed';
  end if;

  if p_status in ('resolved', 'cancelled')
     and v_notes = '' then
    raise exception
      'Add resolution details or a cancellation reason';
  end if;

  if p_status = v_report.status
     and v_notes = v_report.staff_notes then
    return;
  end if;

  select full_name
    into v_name
    from public.profiles
    where id = v_actor;

  update public.maintenance_reports
  set
    status = p_status,
    staff_notes = v_notes,
    handled_by = v_actor,
    resolved_at = case
      when p_status = 'resolved'
        then coalesce(v_report.resolved_at, now())
      else null
    end
  where id = p_report_id;

  insert into public.maintenance_staff_history (
    report_id,
    actor_id,
    actor_name,
    previous_status,
    next_status,
    notes
  )
  values (
    p_report_id,
    v_actor,
    coalesce(v_name, 'Staff'),
    v_report.status,
    p_status,
    v_notes
  );
end;
$$;

revoke all on function public.update_staff_maintenance(
  uuid, timestamptz, text, text
) from public, anon;

grant execute on function public.update_staff_maintenance(
  uuid, timestamptz, text, text
) to authenticated;

commit;