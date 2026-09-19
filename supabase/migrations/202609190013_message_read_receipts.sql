-- Timestamped, recipient-only read receipts for direct conversation messages.
alter table public.messages add column if not exists read_at timestamptz;

update public.messages
set read_at = created_at
where is_read = true and read_at is null;

alter table public.messages
  add constraint messages_read_state_consistent
  check ((is_read = true and read_at is not null)
      or (is_read = false and read_at is null));

drop policy if exists messages_update_policy on public.messages;
revoke update on public.messages from authenticated;

create or replace function public.mark_conversation_messages_read(
  p_conversation_id uuid
) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_read_at timestamptz := now();
begin
  if auth.uid() is null
     or not public.can_access_conversation(p_conversation_id) then
    raise exception 'Forbidden';
  end if;

  update public.messages
  set is_read = true, read_at = v_read_at
  where conversation_id = p_conversation_id
    and sender_id <> auth.uid()
    and is_read = false;

  return v_read_at;
end;
$$;

grant execute on function public.mark_conversation_messages_read(uuid)
  to authenticated;
revoke execute on function public.mark_conversation_messages_read(uuid)
  from public, anon;

comment on column public.messages.read_at is
  'Server timestamp when an authorized conversation participant first viewed an incoming message.';
