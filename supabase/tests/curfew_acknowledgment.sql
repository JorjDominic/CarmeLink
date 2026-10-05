-- Run against a database containing staff, linked tenants, and unlinked tenants.
-- All test requests and decisions are rolled back.
begin;
do $$
declare
  v_linked uuid;
  v_unlinked uuid;
  v_guardian uuid;
  v_owner uuid;
  v_caretaker uuid;
  v_request public.curfew_requests;
  v_actor uuid;
  v_rejected boolean;
begin
  select tenant_id, guardian_id into v_linked, v_guardian
    from public.guardian_tenant_links limit 1;
  select p.id into v_unlinked from public.profiles p
    where p.role = 'tenant' and not exists (
      select 1 from public.guardian_tenant_links l where l.tenant_id = p.id
    ) limit 1;
  select id into v_owner from public.profiles where role = 'owner' limit 1;
  select id into v_caretaker from public.profiles where role = 'caretaker' limit 1;
  if v_linked is null or v_unlinked is null or v_owner is null or v_caretaker is null then
    raise exception 'Tests require linked/unlinked tenants, an owner, and a caretaker';
  end if;

  -- Authenticated role exercises RLS as well as the routing and update trigger.
  execute 'set local role authenticated';
  foreach v_actor in array array[v_owner, v_caretaker] loop
    perform set_config('request.jwt.claim.sub', v_unlinked::text, true);
    select * into v_request from public.submit_curfew_request(
      'Test destination', 'Fallback routing test', now(), now() + interval '1 day', 'overnight_leave'
    );
    if v_request.status <> 'pending_staff' then
      raise exception 'Unlinked overnight leave must route to staff';
    end if;
    perform set_config('request.jwt.claim.sub', v_actor::text, true);
    update public.curfew_requests set staff_decision = 'approved'
      where id = v_request.id returning * into v_request;
    if v_request.status <> 'approved' or v_request.staff_id <> v_actor
       or v_request.staff_decided_at is null or v_request.guardian_decision is not null then
      raise exception 'Staff fallback acknowledgment was not recorded correctly';
    end if;
    v_rejected := false;
    begin
      update public.curfew_requests set staff_decision = 'rejected' where id = v_request.id;
    exception when others then v_rejected := true;
    end;
    if not v_rejected then raise exception 'Finalized acknowledgment must not be overwritten'; end if;
  end loop;

  perform set_config('request.jwt.claim.sub', v_linked::text, true);
  select * into v_request from public.submit_curfew_request(
    'Test destination', 'Late return routing test', now(), now() + interval '1 day', 'late_return'
  );
  if v_request.status <> 'pending_staff' then raise exception 'Late return must route to staff'; end if;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  update public.curfew_requests set staff_decision = 'rejected'
    where id = v_request.id returning * into v_request;
  if v_request.status <> 'rejected' then raise exception 'Staff decline must reject the request'; end if;

  perform set_config('request.jwt.claim.sub', v_linked::text, true);
  select * into v_request from public.submit_curfew_request(
    'Test destination', 'Guardian routing test', now(), now() + interval '1 day', 'overnight_leave'
  );
  if v_request.status <> 'pending_guardian' then raise exception 'Linked overnight leave must route to guardian'; end if;
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  v_rejected := false;
  begin
    update public.curfew_requests set staff_decision = 'approved' where id = v_request.id;
  exception when others then v_rejected := true;
  end;
  if not v_rejected then raise exception 'Staff must not bypass the linked guardian'; end if;
  perform set_config('request.jwt.claim.sub', v_guardian::text, true);
  update public.curfew_requests set guardian_decision = 'approved'
    where id = v_request.id returning * into v_request;
  if v_request.status <> 'approved' or v_request.guardian_id <> v_guardian
     or v_request.guardian_decided_at is null or v_request.staff_decision is not null then
    raise exception 'Guardian acknowledgment must be final without staff sign-off';
  end if;
  execute 'reset role';
end $$;
rollback;
