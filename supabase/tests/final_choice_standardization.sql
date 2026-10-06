-- Final-phase regression: alphabetical configuration order, catch-all Other
-- requirements, and descriptive custom report types mapped to generic workflow.
do $$
declare
  v_owner uuid;
  v_tenant uuid;
  v_other_category uuid;
  v_other_location uuid;
  v_custom_report_type uuid;
  v_maintenance uuid;
  v_report uuid;
  v_failed boolean := false;
  v_suffix text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
begin
  select id into v_owner
  from public.profiles
  where role::text = 'owner'
  limit 1;

  select id into v_tenant
  from public.profiles
  where role::text = 'tenant'
  limit 1;

  if v_owner is null or v_tenant is null then
    raise exception 'Need owner and tenant fixtures';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  insert into public.dormitory_options(group_key, label, sort_order)
  values ('announcement_category', 'Zulu QA ' || v_suffix, 9000);

  insert into public.dormitory_options(group_key, label, sort_order)
  values ('announcement_category', 'Alpha QA ' || v_suffix, 9000);

  insert into public.dormitory_options(group_key, label, sort_order)
  values ('announcement_category', 'Other QA ' || v_suffix, 1);

  if not exists (
    select 1
    from public.dormitory_options alpha
    join public.dormitory_options zulu
      on zulu.group_key = alpha.group_key
    join public.dormitory_options other_choice
      on other_choice.group_key = alpha.group_key
    where alpha.group_key = 'announcement_category'
      and alpha.label = 'Alpha QA ' || v_suffix
      and zulu.label = 'Zulu QA ' || v_suffix
      and other_choice.label = 'Other QA ' || v_suffix
      and alpha.sort_order < zulu.sort_order
      and zulu.sort_order < other_choice.sort_order
  ) then
    raise exception 'Alphabetical / Other-last configuration ordering failed';
  end if;

  select id into v_other_category
  from public.dormitory_options
  where group_key = 'maintenance_category'
    and is_active
    and (
      lower(btrim(label)) in ('other', 'others')
      or lower(btrim(label)) like 'other %'
      or lower(btrim(label)) like 'others %'
    )
  order by sort_order
  limit 1;

  select id into v_other_location
  from public.dormitory_options
  where group_key = 'common_area'
    and is_active
    and (
      lower(btrim(label)) in ('other', 'others')
      or lower(btrim(label)) like 'other %'
      or lower(btrim(label)) like 'others %'
    )
  order by sort_order
  limit 1;

  if v_other_category is null or v_other_location is null then
    raise exception 'Need active maintenance and location Other fixtures';
  end if;

  perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  v_failed := false;
  begin
    insert into public.maintenance_reports(
      tenant_id,
      category,
      category_option_id,
      description,
      location,
      location_option_id,
      urgency
    ) values (
      v_tenant,
      'Other',
      v_other_category,
      'Final phase missing-specific regression report.',
      'Other common area',
      v_other_location,
      'low'
    );
  exception when others then
    if sqlerrm ilike '%specify the maintenance category%'
       or sqlerrm ilike '%specify the maintenance location%' then
      v_failed := true;
    else
      raise;
    end if;
  end;

  if not v_failed then
    raise exception 'Catch-all maintenance report accepted without specific text';
  end if;

  insert into public.maintenance_reports(
    tenant_id,
    category,
    category_option_id,
    specific_category,
    description,
    location,
    location_option_id,
    specific_location,
    urgency
  ) values (
    v_tenant,
    'Other',
    v_other_category,
    'Ceiling moisture',
    'Final phase specific-value regression report.',
    'Other common area',
    v_other_location,
    'Rear stair landing',
    'low'
  ) returning id into v_maintenance;

  if not exists (
    select 1
    from public.maintenance_reports
    where id = v_maintenance
      and specific_category = 'Ceiling moisture'
      and specific_location = 'Rear stair landing'
  ) then
    raise exception 'Specific maintenance Other values were not persisted';
  end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  insert into public.dormitory_options(
    group_key,
    label,
    category_code,
    sort_order
  ) values (
    'report_type',
    'Noise concern QA ' || v_suffix,
    'other',
    9000
  ) returning id into v_custom_report_type;

  perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  insert into public.confidential_reports(
    tenant_id,
    category,
    summary,
    report_type_id
  ) values (
    v_tenant,
    'other',
    'Descriptive custom report type should not require duplicate Other text.',
    v_custom_report_type
  ) returning id into v_report;

  if not exists (
    select 1
    from public.confidential_reports
    where id = v_report
      and report_type_label = 'Noise concern QA ' || v_suffix
      and specific_concern is null
  ) then
    raise exception 'Descriptive custom report type behaved like catch-all Other';
  end if;

  execute 'reset role';
  raise notice 'Final choice standardization checks passed';
end
$$;
