-- Run with the linked database query tool. Uses existing accounts solely as
-- authenticated database identities; no passwords or user details are returned.
-- All application changes occur inside a subtransaction deliberately rolled back.
create temporary table if not exists codex_feature_validation_results(result jsonb);
truncate codex_feature_validation_results;
do $$
declare
  owner_id uuid; caretaker_id uuid; tenant_id uuid; other_id uuid; guardian_id uuid;
  category text; ids uuid[]:='{}'; case_id uuid; appeal_id uuid; backup_id uuid;
  version timestamptz; original_version timestamptz;
  option_id uuid; original_sort integer;
  before_counts jsonb; current_counts jsonb; tracking jsonb;
  checks integer:=0;
begin
  select id into owner_id from public.profiles where role::text='owner' limit 1;
  select id into caretaker_id from public.profiles where role::text='caretaker' limit 1;
  select id into guardian_id from public.profiles where role::text='guardian' limit 1;
  select p.id into tenant_id from public.profiles p where p.role::text='tenant'
    order by (select count(*) from public.conduct_cases c where c.tenant_id=p.id),p.id limit 1;
  select id into other_id from public.profiles where role::text='tenant' and id<>tenant_id limit 1;
  if owner_id is null or caretaker_id is null or tenant_id is null or other_id is null or guardian_id is null then
    raise exception 'Validation needs existing owner, caretaker, guardian and two tenant accounts'; end if;
  select code into category from public.dormitory_options where group_key='conduct_category' and is_active
    and not public.is_catch_all_dormitory_option(id) order by sort_order,id limit 1;
  if category is null then raise exception 'Validation needs an active conduct category'; end if;
  begin
    perform set_config('request.jwt.claim.sub',owner_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true);
    execute 'set local role authenticated';
    if public.current_user_role()::text<>'owner' then raise exception 'Owner role not established'; end if;
    select updated_at into original_version from public.system_maintenance_settings;
    perform public.set_system_maintenance(true,'Rollback-only availability validation',original_version);
    if not (select enabled from public.system_maintenance_settings) then raise exception 'Mode was not saved'; end if;
    checks:=checks+1;
    begin
      perform public.set_system_maintenance(false,'Rollback-only stale version check',original_version);
      raise exception 'Stale maintenance write was allowed';
    exception when serialization_failure then checks:=checks+1; end;
    select updated_at into version from public.system_maintenance_settings;
    perform public.set_system_maintenance(false,'Rollback-only availability validation',version);
    checks:=checks+1;
    select id,sort_order into option_id,original_sort from public.dormitory_options where not is_system order by id limit 1;
    backup_id:=public.create_system_configuration_backup();
    if option_id is not null then
      update public.dormitory_options set sort_order=(original_sort+1)%10000 where id=option_id;
    end if;
    perform public.restore_system_configuration_backup(backup_id);
    if option_id is not null and (select sort_order from public.dormitory_options where id=option_id)<>original_sort then
      raise exception 'Restore did not recover original option'; end if;
    if not exists(select 1 from public.system_maintenance_audit where action='configuration_restored') then
      raise exception 'Restore audit missing'; end if;
    checks:=checks+1;
    before_counts:=public.get_tenant_conduct_status(tenant_id);
    for i in 1..3 loop
      case_id:=public.create_conduct_case(tenant_id,category,'Rollback-only conduct validation',
        'Temporary controlled validation; all records are rolled back.',now()-interval '1 day');
      ids:=array_append(ids,case_id);
      select updated_at into version from public.conduct_cases where id=case_id;
      perform public.publish_conduct_case(case_id,version);
      select updated_at into version from public.conduct_cases where id=case_id;
      perform public.record_conduct_investigation_decision(case_id,version,'confirmed',
        'Rollback-only documented decision',gen_random_uuid());
      current_counts:=public.get_tenant_conduct_status(tenant_id);
      if (current_counts->>'confirmed')::int<>(before_counts->>'confirmed')::int+i then
        raise exception 'Confirmed incident total mismatch'; end if;
      checks:=checks+1;
    end loop;
    if current_counts->>'status'<>'continuous_violations' then raise exception 'Continuous flag missing'; end if;
    if (current_counts->>'recent_confirmed')::int<>(before_counts->>'recent_confirmed')::int+3 then
      raise exception 'Recent incident total mismatch'; end if;
    checks:=checks+1;

    perform set_config('request.jwt.claim.sub',caretaker_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',caretaker_id,'role','authenticated')::text,true);
    perform public.list_conduct_tenant_statuses(0,200);
    tracking:=public.get_conduct_investigation(case_id);
    if tracking->'tenant_status'->>'status'<>'continuous_violations' then raise exception 'Caretaker tracking unavailable'; end if;
    select updated_at into version from public.conduct_cases where id=case_id;
    perform public.issue_conduct_case_warning(case_id,version,'Rollback-only caretaker warning');
    checks:=checks+1;
    begin
      perform public.record_conduct_investigation_decision(case_id,version,'not_confirmed','Rollback-only denial test',gen_random_uuid());
      raise exception 'Caretaker final decision was allowed';
    exception when insufficient_privilege then checks:=checks+1; end;
    select updated_at into version from public.system_maintenance_settings;
    begin
      perform public.set_system_maintenance(true,'Rollback-only caretaker denial',version);
      raise exception 'Caretaker mode change was allowed';
    exception when insufficient_privilege then checks:=checks+1; end;
    begin
      perform public.create_system_configuration_backup();
      raise exception 'Caretaker backup creation was allowed';
    exception when insufficient_privilege then checks:=checks+1; end;
    if exists(select 1 from public.system_configuration_backups) then raise exception 'Caretaker read owner backups'; end if;
    if not exists(select 1 from public.system_maintenance_audit) then raise exception 'Caretaker audit unavailable'; end if;
    checks:=checks+1;

    perform set_config('request.jwt.claim.sub',tenant_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',tenant_id,'role','authenticated')::text,true);
    tracking:=public.get_tenant_conduct_status(tenant_id);
    if tracking->>'status'<>'continuous_violations' then raise exception 'Own tenant status unavailable'; end if;
    if exists(select 1 from public.system_configuration_backups) or exists(select 1 from public.system_maintenance_audit) then
      raise exception 'Tenant read staff maintenance records'; end if;
    checks:=checks+1;
    begin
      perform public.get_tenant_conduct_status(other_id);
      raise exception 'Tenant read another tenant status';
    exception when insufficient_privilege then checks:=checks+1; end;
    begin
      perform public.list_conduct_tenant_statuses();
      raise exception 'Tenant read staff status list';
    exception when insufficient_privilege then checks:=checks+1; end;
    appeal_id:=public.submit_conduct_case_appeal(case_id,'Rollback-only appeal statement for validation.','Controlled validation');
    checks:=checks+1;

    perform set_config('request.jwt.claim.sub',guardian_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',guardian_id,'role','authenticated')::text,true);
    begin
      perform public.get_tenant_conduct_status(tenant_id);
      raise exception 'Guardian read tenant conduct status';
    exception when insufficient_privilege then checks:=checks+1; end;
    if not exists(select 1 from public.system_maintenance_settings) then raise exception 'Guardian cannot read availability'; end if;
    checks:=checks+1;

    perform set_config('request.jwt.claim.sub',caretaker_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',caretaker_id,'role','authenticated')::text,true);
    select updated_at into version from public.conduct_case_appeals where id=appeal_id;
    perform public.decide_conduct_case_appeal(appeal_id,version,'accepted','Rollback-only caretaker appeal review');
    tracking:=public.get_tenant_conduct_status(tenant_id);
    if (tracking->>'confirmed')::int<>(before_counts->>'confirmed')::int+3 then raise exception 'Appeal changed outcome automatically'; end if;
    checks:=checks+1;
    perform set_config('request.jwt.claim.sub',owner_id::text,true);
    perform set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true);
    select updated_at into version from public.conduct_cases where id=case_id;
    perform public.record_conduct_investigation_decision(case_id,version,'overturned',
      'Rollback-only owner correction',gen_random_uuid(),appeal_id);
    tracking:=public.get_tenant_conduct_status(tenant_id);
    if (tracking->>'confirmed')::int<>(before_counts->>'confirmed')::int+2 then raise exception 'Overturn did not remove incident'; end if;
    checks:=checks+1;
    select updated_at into version from public.conduct_cases where id=ids[2];
    perform public.set_conduct_case_review_status(ids[2],version,'dismissed','Rollback-only dismissal validation');
    tracking:=public.get_tenant_conduct_status(tenant_id);
    if (tracking->>'confirmed')::int<>(before_counts->>'confirmed')::int+1 then raise exception 'Dismissal did not remove incident'; end if;
    checks:=checks+1;
    raise exception using errcode='ZV001',message='Validation complete; roll back all application changes';
  exception when sqlstate 'ZV001' then null;
  end;
  insert into codex_feature_validation_results values(jsonb_build_object('checks_passed',checks,
    'application_changes_rolled_back',true,'database_roles_tested',jsonb_build_array('owner','caretaker','tenant','guardian')));
end $$;
select result from codex_feature_validation_results;
