-- Phase 2B regression: an ambiguous/retried addendum request must create
-- only one immutable correction entry.
begin;

do $$
declare
  v_tenant uuid;
  v_report uuid;
  v_report_type uuid;
  v_first uuid;
  v_second uuid;
  v_count integer;
begin
  select id into v_tenant
  from public.profiles
  where role::text = 'tenant'
  limit 1;

  if v_tenant is null then
    raise exception 'Need a tenant fixture';
  end if;

  select id into v_report
  from public.confidential_reports
  where tenant_id = v_tenant
  order by created_at desc
  limit 1;

  if v_report is null then
    select id into v_report_type
    from public.dormitory_options
    where group_key = 'report_type'
      and category_code = 'rule_violation'
      and is_active
    order by sort_order, label
    limit 1;

    if v_report_type is null then
      raise exception 'Need an active rule violation report type';
    end if;

    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.sub', v_tenant::text, true);

    insert into public.confidential_reports(
      tenant_id,
      category,
      summary,
      report_type_id
    ) values (
      v_tenant,
      'rule_violation',
      'Phase 2B addendum idempotency fixture.',
      v_report_type
    ) returning id into v_report;
  else
    execute 'set local role authenticated';
    perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  end if;

  v_first := public.append_confidential_report_addendum(
    v_report,
    'Phase 2B correction should only be stored once.',
    'phase2b-idempotency-request'
  );

  v_second := public.append_confidential_report_addendum(
    v_report,
    'Phase 2B correction should only be stored once.',
    'phase2b-idempotency-request'
  );

  if v_first is distinct from v_second then
    raise exception 'Idempotent retry returned a different addendum';
  end if;

  select count(*) into v_count
  from public.confidential_report_addenda
  where author_id = v_tenant
    and client_request_id = 'phase2b-idempotency-request';

  if v_count <> 1 then
    raise exception 'Retried addendum created % rows instead of one', v_count;
  end if;

  execute 'reset role';
  raise notice 'Phase 2B addendum idempotency check passed';
end
$$;

rollback;
