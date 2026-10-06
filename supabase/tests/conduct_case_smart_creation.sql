-- Final-phase regression for meaningful Other values and conduct-case creation.
-- All changes are rolled back.
begin;

do $$
declare
  v_owner uuid;
  v_tenant uuid;
  v_case uuid;
  v_rejected boolean := false;
  v_detail text;
begin
  select id into v_owner
  from public.profiles
  where role = 'owner'
  limit 1;

  select id into v_tenant
  from public.profiles
  where role = 'tenant'
  limit 1;

  if v_owner is null or v_tenant is null then
    raise exception 'Test requires at least one owner and one tenant';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);

  begin
    perform public.create_conduct_case(
      v_tenant,
      'other',
      'QA missing detail',
      'This test confirms that Other requires a specific category value.',
      now(),
      'manual',
      null,
      null,
      null
    );
  exception when others then
    v_rejected := true;
  end;

  if not v_rejected then
    raise exception 'Other category must require category_detail';
  end if;

  v_case := public.create_conduct_case(
    v_tenant,
    'other',
    'QA specific category',
    'This test confirms that the specific Other category is preserved.',
    now(),
    'other',
    null,
    'Noise-related disturbance',
    'Verbal report from authorized staff'
  );

  select category_detail into v_detail
  from public.conduct_cases
  where id = v_case;

  if v_detail <> 'Noise-related disturbance' then
    raise exception 'Specific conduct category was not preserved';
  end if;

  if not exists (
    select 1
    from public.conduct_cases
    where id = v_case
      and source_detail = 'Verbal report from authorized staff'
  ) then
    raise exception 'Specific conduct source was not preserved';
  end if;

  execute 'reset role';
end $$;

rollback;
