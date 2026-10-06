-- Run against a database with at least one owner and tenant. All writes roll back.
begin;
do $$
declare
  v_tenant uuid;
  v_owner uuid;
  v_caretaker uuid;
  v_report uuid;
  v_staff integer;
  v_count integer;
  v_denied boolean;
begin
  select id into v_tenant from public.profiles where role::text = 'tenant' limit 1;
  select id into v_owner from public.profiles where role::text = 'owner' limit 1;
  select id into v_caretaker from public.profiles where role::text = 'caretaker' limit 1;
  select count(*) into v_staff from public.profiles where role::text in ('owner', 'caretaker');
  if v_tenant is null or v_owner is null or v_caretaker is null then
    raise exception 'Tests require a tenant, owner, and caretaker';
  end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  insert into public.confidential_reports(tenant_id, category, summary)
    values (v_tenant, 'rule_violation', 'Private regression test report content')
    returning id into v_report;
  execute 'reset role';

  select count(*) into v_count from public.app_notifications
    where route_id = v_report and route_type = 'confidential_report';
  if v_count <> v_staff then raise exception 'Missing staff notifications'; end if;
  if exists (
    select 1 from public.app_notifications n join public.profiles p on p.id = n.recipient_id
    where n.route_id = v_report and p.role::text not in ('owner', 'caretaker')
  ) then raise exception 'Confidential report exposed to another role'; end if;
  if exists (
    select 1 from public.app_notifications where route_id = v_report
      and (body like '%Private regression%' or data::text like '%Private regression%')
  ) then raise exception 'Confidential report content leaked into notification'; end if;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  select count(*) into v_count from public.app_notifications where route_id = v_report;
  if v_count <> 1 then raise exception 'Owner inbox RLS cannot read notification'; end if;
  perform set_config('request.jwt.claim.sub', v_caretaker::text, true);
  select count(*) into v_count from public.app_notifications where route_id = v_report;
  if v_count <> 1 then raise exception 'Caretaker inbox cannot read notification'; end if;
  perform public.owner_list_confidential_reports();
  perform public.owner_review_confidential_report(v_report, 'under_review', 'Review in progress');
  perform public.owner_review_confidential_report(v_report, 'under_review', 'Updated private notes');
  perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  select count(*) into v_count from public.app_notifications
    where route_id = v_report and data->>'status' = 'under_review';
  if v_count <> 1 then raise exception 'Tenant update missing or duplicated'; end if;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  perform public.owner_review_confidential_report(v_report, 'resolved', 'Concern has been resolved');
  perform set_config('request.jwt.claim.sub', v_tenant::text, true);
  select count(*) into v_count from public.app_notifications
    where route_id = v_report and data->>'status' = 'resolved';
  if v_count <> 1 then raise exception 'Resolution notification missing'; end if;
  v_denied := false;
  begin
    perform public.owner_list_confidential_reports();
  exception when others then v_denied := true;
  end;
  if not v_denied then raise exception 'Tenant can list all confidential reports'; end if;
  v_denied := false;
  begin
    perform public.owner_review_confidential_report(v_report, 'dismissed', 'Unauthorized review');
  exception when others then v_denied := true;
  end;
  if not v_denied then raise exception 'Tenant can review confidential reports'; end if;
  execute 'reset role';
  select count(*) into v_count from public.confidential_report_audit
    where report_id = v_report and actor_id = v_caretaker and action = 'status_change';
  if v_count <> 2 then raise exception 'Caretaker review audit missing'; end if;
end;
$$;
rollback;
