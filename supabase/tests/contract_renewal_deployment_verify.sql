-- READ ONLY. Run after installing the migration (or before rolling back a
-- transaction trial). This does not create renewals or send notifications.
do $$
declare v_name text;
begin
  if not exists(select 1 from information_schema.columns
    where table_schema='public' and table_name='tenant_contracts'
      and column_name='previous_contract_id' and data_type='uuid') then
    raise exception 'Missing renewal contract link';
  end if;
  if not exists(select 1 from information_schema.columns
    where table_schema='public' and table_name='security_deposit_receipts'
      and column_name='transferred_to_contract_id' and data_type='uuid') then
    raise exception 'Missing deposit transfer link';
  end if;
  if to_regclass('public.tenant_contracts_one_live_renewal') is null then
    raise exception 'Missing unique live renewal index';
  end if;
  foreach v_name in array array['renew_tenant_contract(uuid,date,date,numeric,text)',
    'get_my_contract_for_signing()'] loop
    if to_regprocedure('public.' || v_name) is null then
      raise exception 'Missing function: %',v_name;
    end if;
    if not has_function_privilege('authenticated','public.' || v_name,'EXECUTE')
      or has_function_privilege('anon','public.' || v_name,'EXECUTE') then
      raise exception 'Incorrect app/anonymous grants: %',v_name;
    end if;
  end loop;
  foreach v_name in array array['guard_contract_renewal()',
    'guard_renewal_deposit_receipt()','transfer_renewal_deposit()',
    'guard_move_out_after_renewal()'] loop
    if to_regprocedure('public.' || v_name) is null then
      raise exception 'Missing internal guard: %',v_name;
    end if;
    if has_function_privilege('authenticated','public.' || v_name,'EXECUTE')
      or has_function_privilege('anon','public.' || v_name,'EXECUTE') then
      raise exception 'Internal guard is exposed: %',v_name;
    end if;
  end loop;
  foreach v_name in array array['tenant_contracts_renewal_guard',
    'tenant_contracts_transfer_renewal_deposit','security_deposit_receipts_renewal_guard',
    'move_out_cases_renewal_guard','receive_deposit_on_contract_creation',
    'tenant_contracts_protect_signed_terms','guard_contract_price_terms',
    'tenant_contracts_generate_billing'] loop
    if not exists(select 1 from pg_trigger where tgname=v_name
      and not tgisinternal and tgenabled in ('O','A')
      and tgrelid in ('public.tenant_contracts'::regclass,
        'public.security_deposit_receipts'::regclass,'public.move_out_cases'::regclass)) then
      raise exception 'Missing or disabled trigger: %',v_name;
    end if;
  end loop;
  if exists(select 1 from pg_class where oid in
    ('public.tenant_contracts'::regclass,'public.security_deposit_receipts'::regclass)
    and not relrowsecurity) then raise exception 'Contract/deposit RLS is disabled'; end if;
end;
$$;

select 'renewal_schema_and_permissions_verified' as result;
