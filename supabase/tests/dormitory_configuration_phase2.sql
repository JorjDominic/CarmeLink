-- Phase 2A regression: owner-managed choices, snapshots, Other validation,
-- and append-only confidential report corrections.
do $$
declare
  v_tenant uuid;
  v_owner uuid;
  v_caretaker uuid;
  v_report_type uuid;
  v_other_type uuid;
  v_maintenance_type uuid;
  v_report uuid;
  v_maintenance uuid;
  v_denied boolean;
  v_payload jsonb;
begin
  select id into v_tenant from public.profiles where role::text = 'tenant' limit 1;
  select id into v_owner from public.profiles where role::text = 'owner' limit 1;
  select id into v_caretaker from public.profiles where role::text = 'caretaker' limit 1;

  if v_tenant is null or v_owner is null or v_caretaker is null then
    raise exception 'Need owner, caretaker, and tenant fixtures';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into public.dormitory_options(
    group_key, label, category_code, sort_order
  ) values (
    'report_type', 'Unauthorized visitor QA', 'rule_violation', 50
  ) returning id into v_report_type;

  insert into public.dormitory_options(
    group_key, label, sort_order
  ) values (
    'maintenance_category', 'QA fixture category', 50
  ) returning id into v_maintenance_type;

  select id into v_other_type
  from public.dormitory_options
  where group_key = 'report_type' and code = 'other';

  perform set_config('request.jwt.claim.sub', v_caretaker::text, true);
  v_denied := false;
  begin
    insert into public.dormitory_options(group_key, label, sort_order)
    values ('common_area', 'Caretaker forbidden option', 51);
  exception when insufficient_privilege then
    v_denied := true;
  when others then
    if sqlerrm ilike '%row-level security%' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then
    raise exception 'Caretaker changed owner-only configuration';
  end if;

  perform set_config('request.jwt.claim.sub', v_tenant::text, true);

  insert into public.confidential_reports(
    tenant_id, category, summary, report_type_id
  ) values (
    v_tenant,
    'rule_violation',
    'Regression original confidential report text.',
    v_report_type
  ) returning id into v_report;

  if not exists (
    select 1 from public.confidential_reports
    where id = v_report
      and category = 'rule_violation'
      and report_type_label = 'Unauthorized visitor QA'
      and summary = 'Regression original confidential report text.'
  ) then
    raise exception 'Configured report type was not snapshotted correctly';
  end if;

  insert into public.confidential_report_addenda(report_id, body)
  values (v_report, 'Additional details are appended without changing the original.');

  v_denied := false;
  begin
    update public.confidential_report_addenda
    set body = 'Attempted overwrite'
    where report_id = v_report;
  exception when insufficient_privilege then
    v_denied := true;
  when others then
    if sqlerrm ilike '%permission denied%' or sqlerrm ilike '%row-level security%' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then
    raise exception 'Append-only report correction was mutable';
  end if;

  v_denied := false;
  begin
    insert into public.confidential_reports(
      tenant_id, category, summary, report_type_id
    ) values (
      v_tenant,
      'other',
      'Other report without the required specific concern.',
      v_other_type
    );
  exception when others then
    if sqlerrm ilike '%specify the concern%' then
      v_denied := true;
    else
      raise;
    end if;
  end;
  if not v_denied then
    raise exception 'Other report was accepted without a specific concern';
  end if;

  insert into public.maintenance_reports(
    tenant_id,
    category,
    category_option_id,
    description,
    location,
    urgency
  ) values (
    v_tenant,
    'ignored snapshot label',
    v_maintenance_type,
    'QA maintenance report created from a configured category.',
    'Other common area',
    'low'
  ) returning id into v_maintenance;

  if not exists (
    select 1 from public.maintenance_reports
    where id = v_maintenance and category = 'QA fixture category'
  ) then
    raise exception 'Maintenance category snapshot failed';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  update public.dormitory_options
  set label = 'Renamed visitor concern QA', is_active = false
  where id = v_report_type;

  v_payload := public.list_confidential_reports_v2();
  if not exists (
    select 1
    from jsonb_array_elements(v_payload) item
    where item->>'id' = v_report::text
      and item->>'report_type_label' = 'Unauthorized visitor QA'
  ) then
    raise exception 'Historical report label changed after configuration rename';
  end if;

  if jsonb_array_length(public.list_confidential_report_addenda(v_report)) <> 1 then
    raise exception 'Addendum audit entry missing';
  end if;

  execute 'reset role';
  raise notice 'Phase 2A configuration/report workflow checks passed';
end
$$;
