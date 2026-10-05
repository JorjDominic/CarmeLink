begin;
do $$
declare
  v_tenant uuid;
  v_staff uuid;
  v_other_staff uuid;
  v_thread uuid;
  v_message uuid;
  v_count integer;
  v_blocked boolean;
begin
  select id into v_tenant from public.profiles where role::text='tenant' limit 1;
  select id into v_staff from public.profiles where role::text='owner' limit 1;
  select id into v_other_staff from public.profiles where role::text='caretaker' limit 1;
  if v_tenant is null or v_staff is null or v_other_staff is null then
    raise exception 'Tests require a tenant, owner, and caretaker';
  end if;
  execute 'set local role authenticated';
  perform set_config('request.jwt.claim.sub',v_tenant::text,true);
  select count(*) into v_count from public.list_messaging_staff();
  if v_count < 2 then raise exception 'Owner and caretaker must be visible without messages'; end if;
  v_thread := public.get_or_create_direct_staff_conversation(v_staff);
  if public.get_or_create_direct_staff_conversation(v_staff) <> v_thread then
    raise exception 'Repeated contact selection must reuse the thread';
  end if;
  if not public.can_access_conversation(v_thread) then raise exception 'Tenant cannot access own thread'; end if;
  insert into public.messages(conversation_id,sender_id,sender_role,body)
    values(v_thread,v_tenant,'tenant','Private message test') returning id into v_message;

  perform set_config('request.jwt.claim.sub',v_other_staff::text,true);
  if public.can_access_conversation(v_thread) then raise exception 'Unrelated staff can access private chat'; end if;
  select count(*) into v_count from public.conversations where id=v_thread;
  if v_count <> 0 then raise exception 'RLS exposed private thread to unrelated staff'; end if;
  select count(*) into v_count from public.messages where id=v_message;
  if v_count <> 0 then raise exception 'RLS exposed private message to unrelated staff'; end if;
  v_blocked := false;
  begin
    insert into public.messages(conversation_id,sender_id,sender_role,body)
      values(v_thread,v_other_staff,'caretaker','Unauthorized');
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unrelated staff can send into private chat'; end if;
  v_blocked:=false;
  begin
    perform public.mark_conversation_messages_read(v_thread);
  exception when others then v_blocked:=true;
  end;
  if not v_blocked then raise exception 'Unrelated staff can mark messages read'; end if;

  perform set_config('request.jwt.claim.sub',v_staff::text,true);
  if not public.can_access_conversation(v_thread) then raise exception 'Recipient cannot access private chat'; end if;
  perform public.mark_conversation_messages_read(v_thread);
  select count(*) into v_count from public.messages where id=v_message and is_read;
  if v_count <> 1 then raise exception 'Recipient read receipt failed'; end if;
  v_thread:=public.get_or_create_direct_staff_conversation(v_other_staff);
  perform set_config('request.jwt.claim.sub',v_other_staff::text,true);
  if public.get_or_create_direct_staff_conversation(v_staff) <> v_thread then
    raise exception 'Staff pair must reuse one thread in both directions';
  end if;
  execute 'reset role';
end $$;
rollback;
