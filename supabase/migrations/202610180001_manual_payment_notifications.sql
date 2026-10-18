begin;

-- Persist manual payment alerts with the ledger write. The existing server_push
-- queue handles FCM retries independently of the app and payment request.
create function public.notify_manual_payment_event() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_event text;
  v_title text;
  v_body text;
  v_name text;
  v_key text;
begin
  -- Gateway settlement already has its own notifications and retry handling.
  -- Deposits have a separate receipt workflow.
  if new.gateway_session_id is not null or exists (
    select 1 from public.billing_charges where id = new.charge_id and category = 'deposit'
  ) then return new; end if;

  if tg_op = 'INSERT' then
    if new.status = 'pending_verification' then
      v_event := 'submitted';
      v_title := 'Payment proof submitted';
    elsif new.status = 'verified' and new.staff_request_id is not null then
      v_event := 'received';
      v_title := 'Payment received';
    else return new;
    end if;
  elsif old.status = 'pending_verification' and new.status in ('verified', 'rejected') then
    v_event := new.status;
    v_title := case when new.status = 'verified' then 'Payment approved' else 'Payment rejected' end;
  else return new;
  end if;

  select coalesce(nullif(btrim(full_name), ''), 'Tenant') into v_name
    from public.profiles where id = new.tenant_id;
  v_body := coalesce(v_name, 'Tenant') || ': PHP ' || new.amount::text ||
    case v_event
      when 'submitted' then ' payment proof was submitted and is awaiting staff review.'
      when 'received' then ' face-to-face payment was recorded and credited by staff.'
      when 'verified' then ' payment was approved and credited.'
      else ' payment proof was rejected.' ||
        case when nullif(btrim(new.review_notes), '') is not null
          then ' Reason: ' || new.review_notes else '' end
    end;
  v_key := 'manual-payment:' || new.id::text || ':' || v_event;

  -- Include the acting tenant/staff too: both sides need a saved confirmation.
  -- UNION prevents duplicate recipients, including duplicate guardian links.
  insert into public.app_notifications (
    recipient_id, notification_type, title, body, route_type, route_id, data
  )
  select recipient.id, 'payment', v_title, left(v_body, 500), 'payment', new.charge_id,
    jsonb_build_object('server_push', true, 'event_key', v_key,
      'payment_id', new.charge_id, 'transaction_id', new.id,
      'tenant_id', new.tenant_id, 'amount', new.amount, 'status', new.status,
      'event', v_event, 'actor_id', auth.uid())
  from (
    select new.tenant_id as id
    union select guardian_id from public.guardian_tenant_links where tenant_id = new.tenant_id
    union select id from public.profiles where role::text in ('owner', 'caretaker')
  ) recipient
  where not exists (
    select 1 from public.app_notifications n
    where n.recipient_id = recipient.id and n.data->>'event_key' = v_key
  );
  return new;
end $$;

revoke all on function public.notify_manual_payment_event() from public, anon, authenticated;
create trigger payment_transaction_notification
after insert or update of status on public.payment_transactions
for each row execute function public.notify_manual_payment_event();

commit;
