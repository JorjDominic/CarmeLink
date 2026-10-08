begin;

-- Maya remains unavailable until the gateway and verified settlement handler
-- have been configured by the backend. Clients cannot declare it ready.
create table public.payment_collection_settings (
  id boolean primary key default true check (id),
  mode text not null default 'manual' check (mode in ('manual', 'maya')),
  maya_ready boolean not null default false,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now(),
  check (mode <> 'maya' or maya_ready)
);
insert into public.payment_collection_settings (id) values (true);
alter table public.payment_collection_settings enable row level security;
revoke all on public.payment_collection_settings from anon, authenticated;
grant select on public.payment_collection_settings to authenticated;
create policy payment_collection_settings_read
  on public.payment_collection_settings for select to authenticated using (true);

create table public.payment_collection_settings_history (
  id bigint generated always as identity primary key,
  previous_mode text not null,
  new_mode text not null,
  changed_by uuid not null references public.profiles(id),
  changed_at timestamptz not null default now()
);
alter table public.payment_collection_settings_history enable row level security;
revoke all on public.payment_collection_settings_history from anon, authenticated;
grant select on public.payment_collection_settings_history to authenticated;
create policy payment_collection_settings_history_owner_read
  on public.payment_collection_settings_history for select to authenticated
  using (public.current_user_role()::text = 'owner');

create function public.set_payment_collection_mode(p_mode text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_settings public.payment_collection_settings;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text, '') <> 'owner' then
    raise exception 'Only the owner can change payment collection mode';
  end if;
  if p_mode is null or p_mode not in ('manual', 'maya') then
    raise exception 'Choose manual or Maya payment collection';
  end if;
  select * into strict v_settings from public.payment_collection_settings where id for update;
  if p_mode = 'maya' and not v_settings.maya_ready then
    raise exception 'Maya automatic payments are not connected yet. Continue using manual receipt submission.';
  end if;
  if v_settings.mode <> p_mode then
    insert into public.payment_collection_settings_history(previous_mode,new_mode,changed_by)
      values(v_settings.mode,p_mode,auth.uid());
    update public.payment_collection_settings
      set mode=p_mode,updated_by=auth.uid(),updated_at=now() where id
      returning * into v_settings;
  end if;
  return to_jsonb(v_settings);
end; $$;
revoke all on function public.set_payment_collection_mode(text) from public, anon;
grant execute on function public.set_payment_collection_mode(text) to authenticated;

commit;
