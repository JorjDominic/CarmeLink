begin;

create or replace function public.notify_verified_paymongo_payment(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare p public.paymongo_payment_sessions; v_title text; v_body text; v_name text;
begin
  select * into p from public.paymongo_payment_sessions where id=p_session_id;
  if not found or p.status<>'succeeded' or not p.notification_pending then return; end if;
  select coalesce(nullif(btrim(full_name),''),'the tenant') into v_name from public.profiles where id=p.tenant_id;
  v_title := 'Payment confirmed' || case when p.environment='test' then ' (TEST)' else '' end;
  v_body := 'Payment of PHP ' || (p.amount_centavos::numeric/100)::numeric(12,2)::text ||
    ' for ' || coalesce(v_name,'the tenant') || ' was confirmed through PayMongo QR Ph.' ||
    case when p.environment='test' then ' (TEST)' else '' end;
  begin
    perform public.emit_tenant_circle_notification(p.tenant_id,true,true,'payment',v_title,v_body,'payment',p.charge_id,
      jsonb_build_object('payment_session_id',p.id,'bill_breakdown',p.bill_breakdown,'environment',p.environment),
      'paymongo-paid:'||p.id::text,0);
    perform public.emit_staff_notification('payment',v_title,v_body,'payment',p.charge_id,
      jsonb_build_object('payment_session_id',p.id,'tenant_id',p.tenant_id,'environment',p.environment),
      'paymongo-paid:'||p.id::text,0);
    update public.paymongo_payment_sessions set notification_pending=false where id=p.id;
  exception when others then
    -- Payment confirmation remains committed; existing checks retry delivery.
    null;
  end;
end $$;
revoke all on function public.notify_verified_paymongo_payment(uuid) from public,anon,authenticated;
grant execute on function public.notify_verified_paymongo_payment(uuid) to service_role;

-- Normalize saved inbox text without resending already-created notifications.
update public.app_notifications
set title='Payment confirmed (TEST)',
    body='Payment was confirmed through PayMongo QR Ph. (TEST)'
where notification_type='payment' and title='Test payment confirmed';

commit;
