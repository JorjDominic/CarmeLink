-- Migration: 202609190001_messaging_module.sql
-- Implements the real-time two-way Messaging Module for Carmelita's Dormitory.
-- Supports:
--   1. Tenant <-> Management (Owner / Caretaker)
--   2. Guardian <-> Management (Owner / Caretaker)
--   3. Internal Staff (Owner <-> Caretaker)

-- 1. Create conversations table
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (
    type in ('tenant_management', 'guardian_management', 'internal_staff')
  ),
  tenant_id uuid references public.profiles(id) on delete cascade,
  guardian_id uuid references public.profiles(id) on delete cascade,
  last_message_preview text,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint conversations_participant_type_check check (
    (type = 'tenant_management' and tenant_id is not null and guardian_id is null) or
    (type = 'guardian_management' and guardian_id is not null) or
    (type = 'internal_staff' and tenant_id is null and guardian_id is null)
  )
);

-- Indices for rapid lookups and uniqueness guarantees
create unique index if not exists conversations_tenant_management_uniq
  on public.conversations(tenant_id)
  where type = 'tenant_management';

create unique index if not exists conversations_guardian_management_uniq
  on public.conversations(guardian_id)
  where type = 'guardian_management' and tenant_id is null;

create unique index if not exists conversations_guardian_tenant_management_uniq
  on public.conversations(guardian_id, tenant_id)
  where type = 'guardian_management' and tenant_id is not null;

create unique index if not exists conversations_internal_staff_uniq
  on public.conversations(type)
  where type = 'internal_staff';

create index if not exists conversations_last_message_at_idx
  on public.conversations(last_message_at desc);

create index if not exists conversations_type_idx
  on public.conversations(type);

-- 2. Create messages table
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_role text not null check (
    sender_role in ('tenant', 'guardian', 'owner', 'caretaker')
  ),
  body text not null check (
    char_length(trim(body)) between 1 and 2000
  ),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Indices for message sorting, conversations, and unread counts
create index if not exists messages_conversation_created_at_idx
  on public.messages(conversation_id, created_at asc);

create index if not exists messages_sender_id_idx
  on public.messages(sender_id);

create index if not exists messages_unread_idx
  on public.messages(conversation_id, is_read)
  where not is_read;

-- 3. Trigger to keep conversations updated automatically on message insertion
create or replace function public.on_message_inserted_sync_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
  set
    last_message_preview = substring(new.body from 1 for 150),
    last_message_at = new.created_at,
    updated_at = now()
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trigger_sync_conversation_on_message on public.messages;
create trigger trigger_sync_conversation_on_message
  after insert on public.messages
  for each row
  execute function public.on_message_inserted_sync_conversation();

-- 4. Helper function: verify if authenticated user has access to a conversation
create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conv record;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    return false;
  end if;

  -- Dormitory staff (Owner and Caretaker) have access to management threads
  if public.is_staff() then
    return true;
  end if;

  select type, tenant_id, guardian_id
  into v_conv
  from public.conversations
  where id = p_conversation_id;

  if not found then
    return false;
  end if;

  -- Tenants access their own thread
  if v_conv.type = 'tenant_management' and v_conv.tenant_id = v_uid then
    return true;
  end if;

  -- Guardians access their own thread
  if v_conv.type = 'guardian_management' and v_conv.guardian_id = v_uid then
    return true;
  end if;

  return false;
end;
$$;

-- Revoke public execution, grant authenticated execution
revoke all on function public.can_access_conversation(uuid) from public, anon;
grant execute on function public.can_access_conversation(uuid) to authenticated;

-- 5. Row Level Security (RLS) configuration
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- Grants
grant select, insert, update on table public.conversations to authenticated;
grant select, insert, update on table public.messages to authenticated;

-- Conversations RLS Policies
drop policy if exists "conversations_select_policy" on public.conversations;
create policy "conversations_select_policy"
  on public.conversations for select
  to authenticated
  using (
    public.is_staff() or
    tenant_id = auth.uid() or
    guardian_id = auth.uid()
  );

drop policy if exists "conversations_insert_policy" on public.conversations;
create policy "conversations_insert_policy"
  on public.conversations for insert
  to authenticated
  with check (
    public.is_staff() or
    (type = 'tenant_management' and tenant_id = auth.uid()) or
    (type = 'guardian_management' and guardian_id = auth.uid())
  );

drop policy if exists "conversations_update_policy" on public.conversations;
create policy "conversations_update_policy"
  on public.conversations for update
  to authenticated
  using (
    public.is_staff() or
    tenant_id = auth.uid() or
    guardian_id = auth.uid()
  )
  with check (
    public.is_staff() or
    tenant_id = auth.uid() or
    guardian_id = auth.uid()
  );

-- Messages RLS Policies
drop policy if exists "messages_select_policy" on public.messages;
create policy "messages_select_policy"
  on public.messages for select
  to authenticated
  using (
    public.can_access_conversation(conversation_id)
  );

drop policy if exists "messages_insert_policy" on public.messages;
create policy "messages_insert_policy"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid() and
    public.can_access_conversation(conversation_id)
  );

drop policy if exists "messages_update_policy" on public.messages;
create policy "messages_update_policy"
  on public.messages for update
  to authenticated
  using (
    public.can_access_conversation(conversation_id)
  )
  with check (
    public.can_access_conversation(conversation_id)
  );

-- 6. Enable Supabase Realtime for instant two-way messaging
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

