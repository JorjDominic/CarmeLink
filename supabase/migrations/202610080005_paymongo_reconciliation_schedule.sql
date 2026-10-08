begin;
create function private.dispatch_paymongo_reconciliation() returns void
language plpgsql security definer set search_path = '' as $$
declare v_config private.report_push_dispatch_config%rowtype;
begin
  if not exists(select 1 from public.payment_collection_settings where id and paymongo_ready) then return; end if;
  if not exists(select 1 from public.paymongo_payment_sessions where status in ('creating','pending','needs_review')
    and coalesce(last_checked_at,created_at)<now()-interval '5 minutes') then return; end if;
  select * into strict v_config from private.report_push_dispatch_config where singleton;
  perform net.http_post(
    url:=replace(v_config.endpoint,'process-report-pushes','reconcile-paymongo-payments'),
    headers:=jsonb_build_object('Authorization','Bearer '||v_config.bearer_token,'Content-Type','application/json'),
    body:='{}'::jsonb,timeout_milliseconds:=10000);
end $$;
revoke all on function private.dispatch_paymongo_reconciliation() from public,anon,authenticated;
select cron.schedule('paymongo-payment-reconciliation','*/5 * * * *','select private.dispatch_paymongo_reconciliation();');
commit;
