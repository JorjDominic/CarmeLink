begin;
create table public.room_transfer_notice_acknowledgments (
  transfer_id uuid primary key references public.room_transfers(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id),
  document_sha256 text not null check(document_sha256 ~ '^[a-f0-9]{64}$'),
  acknowledged_at timestamptz not null default now()
);
alter table public.room_transfer_notice_acknowledgments enable row level security;
revoke all on public.room_transfer_notice_acknowledgments from anon,authenticated,service_role;
grant select on public.room_transfer_notice_acknowledgments to authenticated,service_role;
create policy room_transfer_notice_read on public.room_transfer_notice_acknowledgments for select to authenticated
using(public.can_read_room_transfer(transfer_id));
create function public.acknowledge_room_transfer_notice(p_id uuid,p_document_sha256 text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.room_transfers;
begin
  select * into t from public.room_transfers where id=p_id for update;
  if auth.uid() is null or public.current_user_role()::text is distinct from 'tenant'
    or t.id is null or t.tenant_id<>auth.uid() then raise exception 'Only the moving tenant may acknowledge this notice' using errcode='42501'; end if;
  if t.status<>'awaiting_signatures' or t.document_path is null or p_document_sha256 is null
    or t.document_sha256 is distinct from p_document_sha256 then raise exception 'Review the current published amendment before acknowledging'; end if;
  insert into public.room_transfer_notice_acknowledgments(transfer_id,tenant_id,document_sha256)
    values(t.id,auth.uid(),t.document_sha256) on conflict(transfer_id) do nothing;
end $$;
create function public.guard_room_transfer_notice() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.status='completed' and old.status is distinct from 'completed' and not exists(
    select 1 from public.room_transfer_notice_acknowledgments a where a.transfer_id=new.id
      and a.tenant_id=new.tenant_id and a.document_sha256=new.document_sha256) then
    raise exception 'The moving tenant must review and acknowledge the room transfer notice before completion';
  end if;
  return new;
end $$;
create trigger require_room_transfer_notice before update on public.room_transfers
for each row execute function public.guard_room_transfer_notice();
create function public.protect_room_transfer_notice() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Room transfer acknowledgments cannot be edited or deleted'; end $$;
create trigger room_transfer_notice_immutable before update or delete on public.room_transfer_notice_acknowledgments
for each row execute function public.protect_room_transfer_notice();
revoke all on function public.acknowledge_room_transfer_notice(uuid,text) from public,anon,service_role;
grant execute on function public.acknowledge_room_transfer_notice(uuid,text) to authenticated;
revoke all on function public.guard_room_transfer_notice(),public.protect_room_transfer_notice() from public,anon,authenticated,service_role;
alter publication supabase_realtime add table public.room_transfer_notice_acknowledgments;
notify pgrst,'reload schema';
commit;
