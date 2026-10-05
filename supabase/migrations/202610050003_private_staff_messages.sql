-- Private participant-to-staff threads; legacy shared management chats remain.
alter table public.conversations
  add column direct_participant_id uuid references public.profiles(id) on delete cascade,
  add column direct_staff_id uuid references public.profiles(id) on delete cascade;
alter table public.conversations drop constraint conversations_type_check;
alter table public.conversations add constraint conversations_type_check
  check (type in ('tenant_management','guardian_management','internal_staff','direct_staff'));
alter table public.conversations drop constraint conversations_participant_type_check;
alter table public.conversations add constraint conversations_participant_type_check check (
  (type = 'direct_staff' and tenant_id is null and guardian_id is null
    and direct_participant_id is not null and direct_staff_id is not null
    and direct_participant_id <> direct_staff_id)
  or (type <> 'direct_staff' and direct_participant_id is null and direct_staff_id is null and (
    (type = 'tenant_management' and tenant_id is not null and guardian_id is null)
    or (type = 'guardian_management' and guardian_id is not null)
    or (type = 'internal_staff' and tenant_id is null and guardian_id is null)))
);
create unique index conversations_direct_staff_pair on public.conversations (
  least(direct_participant_id, direct_staff_id), greatest(direct_participant_id, direct_staff_id)
) where type = 'direct_staff';

create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and exists (
    select 1 from public.conversations c where c.id = p_conversation_id and (
      (c.type = 'direct_staff' and auth.uid() in (c.direct_participant_id,c.direct_staff_id))
      or (c.type <> 'direct_staff' and (
        public.is_staff() or (c.type = 'tenant_management' and c.tenant_id = auth.uid())
        or (c.type = 'guardian_management' and c.guardian_id = auth.uid())))
    )
  );
$$;

drop policy conversations_select_policy on public.conversations;
create policy conversations_select_policy on public.conversations for select to authenticated
  using (public.can_access_conversation(id));

-- Direct threads are created only by the validated RPC. Existing permissive
-- staff policies must not allow unrelated staff to create or alter them.
drop policy conversations_insert_policy on public.conversations;
create policy conversations_insert_policy on public.conversations for insert to authenticated
  with check (type <> 'direct_staff' and (public.is_staff()
    or (type = 'tenant_management' and tenant_id = auth.uid())
    or (type = 'guardian_management' and guardian_id = auth.uid())));
drop policy conversations_update_policy on public.conversations;
create policy conversations_update_policy on public.conversations for update to authenticated
  using (type <> 'direct_staff' and public.can_access_conversation(id))
  with check (type <> 'direct_staff' and public.can_access_conversation(id));
create or replace function public.protect_conversation_participants()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.type is distinct from old.type or new.tenant_id is distinct from old.tenant_id
    or new.guardian_id is distinct from old.guardian_id
    or new.direct_participant_id is distinct from old.direct_participant_id
    or new.direct_staff_id is distinct from old.direct_staff_id then
    raise exception 'Conversation participants cannot be changed';
  end if;
  return new;
end $$;
create trigger protect_conversation_participants before update on public.conversations
  for each row execute function public.protect_conversation_participants();

create function public.list_messaging_staff()
returns table(id uuid, full_name text, role text)
language sql stable security definer set search_path = '' as $$
  select p.id,p.full_name,p.role::text from public.profiles p
  where auth.uid() is not null and p.role::text in ('owner','caretaker')
    and p.id <> auth.uid() order by p.role::text desc,p.full_name,p.id;
$$;

create function public.list_my_direct_staff_conversations()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(c) || jsonb_build_object(
    'direct_peer_id',p.id,'direct_peer_name',p.full_name,'direct_peer_role',p.role::text,
    'unread_count',(select count(*) from public.messages m where m.conversation_id=c.id
      and m.sender_id <> auth.uid() and not m.is_read)
  ) order by c.last_message_at desc),'[]'::jsonb)
  from public.conversations c join public.profiles p on p.id = case
    when c.direct_participant_id=auth.uid() then c.direct_staff_id else c.direct_participant_id end
  where c.type='direct_staff' and auth.uid() in (c.direct_participant_id,c.direct_staff_id);
$$;

create function public.get_or_create_direct_staff_conversation(p_staff_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null or p_staff_id = auth.uid() or not exists (
    select 1 from public.profiles where id=p_staff_id and role::text in ('owner','caretaker')
  ) then raise exception 'Select another owner or caretaker account'; end if;
  insert into public.conversations(type,direct_participant_id,direct_staff_id)
    values('direct_staff',auth.uid(),p_staff_id)
    on conflict (least(direct_participant_id,direct_staff_id), greatest(direct_participant_id,direct_staff_id))
      where type='direct_staff' do nothing;
  select id into v_id from public.conversations where type='direct_staff'
    and least(direct_participant_id,direct_staff_id)=least(auth.uid(),p_staff_id)
    and greatest(direct_participant_id,direct_staff_id)=greatest(auth.uid(),p_staff_id);
  return v_id;
end $$;
revoke all on function public.list_messaging_staff() from public,anon;
revoke all on function public.list_my_direct_staff_conversations() from public,anon;
revoke all on function public.get_or_create_direct_staff_conversation(uuid) from public,anon;
grant execute on function public.list_messaging_staff(), public.list_my_direct_staff_conversations(),
  public.get_or_create_direct_staff_conversation(uuid) to authenticated;
