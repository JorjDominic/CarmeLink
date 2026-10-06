begin;

-- Cart scope is expanded inside the RPC. Notify from committed allocations,
-- using the actual tenant share, for individual, selected-room and all-room carts.
create or replace function public.notify_utility_allocation_created()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_charge public.billing_charges%rowtype;
begin
  select * into strict v_charge
  from public.billing_charges
  where id = new.charge_id;

  insert into public.app_notifications (
    recipient_id, notification_type, title, body, route_type, route_id, data
  )
  select
    new.tenant_id,
    'payment',
    'New utility bill issued',
    left(v_charge.title, 150) || ': PHP ' || new.allocated_amount::text
      || ' is due on ' || v_charge.due_date::text || '.',
    'payment',
    new.charge_id,
    jsonb_build_object(
      'payment_id', new.charge_id,
      'batch_item_id', new.batch_item_id,
      'amount', new.allocated_amount,
      'tenant_id', new.tenant_id,
      'server_push', true
    )
  union all
  select
    link.guardian_id,
    'payment',
    'New utility bill for linked resident',
    left(v_charge.title, 150) || ': PHP ' || new.allocated_amount::text
      || ' is due on ' || v_charge.due_date::text || '.',
    'payment',
    new.charge_id,
    jsonb_build_object(
      'payment_id', new.charge_id,
      'batch_item_id', new.batch_item_id,
      'amount', new.allocated_amount,
      'tenant_id', new.tenant_id,
      'server_push', true
    )
  from public.guardian_tenant_links link
  where link.tenant_id = new.tenant_id;

  return new;
end;
$$;

revoke all on function public.notify_utility_allocation_created()
  from public, anon, authenticated;

create trigger utility_allocation_created_notification
after insert on public.utility_charge_allocations
for each row execute function public.notify_utility_allocation_created();

-- Notifications created in one transaction share a timestamp. The ID tie-breaker
-- keeps pagination deterministic when multiple tenants/guardians are notified at once.
create index if not exists app_notifications_recipient_cursor_idx
  on public.app_notifications(recipient_id, created_at desc, id desc);

commit;
