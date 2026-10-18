begin;
create table public.system_maintenance_settings (
  id boolean primary key default true check(id),
  enabled boolean not null default false,
  message text not null default 'The system is undergoing maintenance. Please try again later.'
    check(char_length(btrim(message)) between 5 and 500),
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.system_maintenance_settings(id) values(true);
create table public.system_maintenance_audit (
  id uuid primary key default gen_random_uuid(), actor_id uuid not null,
  action text not null, details jsonb not null default '{}', created_at timestamptz not null default clock_timestamp()
);
create table public.system_configuration_backups (
  id uuid primary key default gen_random_uuid(), created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(), payload jsonb not null
);
alter table public.system_maintenance_settings enable row level security;
alter table public.system_maintenance_audit enable row level security;
alter table public.system_configuration_backups enable row level security;
revoke all on public.system_maintenance_settings,public.system_maintenance_audit,public.system_configuration_backups from public,anon,authenticated;
grant select on public.system_maintenance_settings,public.system_maintenance_audit,public.system_configuration_backups to authenticated;
create policy "authenticated maintenance notice" on public.system_maintenance_settings for select to authenticated using(true);
create policy "staff maintenance audit" on public.system_maintenance_audit for select to authenticated using((select public.is_staff()));
create policy "owner configuration backups" on public.system_configuration_backups for select to authenticated using((select public.current_user_role())::text='owner');

create function public.set_system_maintenance(p_enabled boolean,p_message text,p_expected_updated_at timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare s public.system_maintenance_settings;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may change maintenance mode' using errcode='42501'; end if;
  select * into s from public.system_maintenance_settings where id for update;
  if p_expected_updated_at is null or s.updated_at is distinct from p_expected_updated_at then
    raise exception 'Settings changed. Refresh before saving.' using errcode='40001'; end if;
  if p_enabled is null or p_message is null or char_length(btrim(p_message)) not between 5 and 500 then
    raise exception 'A message of 5 to 500 characters is required'; end if;
  update public.system_maintenance_settings set enabled=p_enabled,message=btrim(p_message),updated_at=clock_timestamp() where id;
  insert into public.system_maintenance_audit(actor_id,action,details) values(auth.uid(),'maintenance_mode_changed',
    jsonb_build_object('enabled',p_enabled,'message',btrim(p_message)));
end $$;

create function public.create_system_configuration_backup() returns uuid
language plpgsql security definer set search_path='' as $$
declare backup_id uuid; snapshot jsonb;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may back up configuration' using errcode='42501'; end if;
  select jsonb_build_object('format','carmelink-configuration-v1','options',
    coalesce(jsonb_agg(to_jsonb(o) order by o.id),'[]'::jsonb)) into snapshot
    from public.dormitory_options o where not o.is_system;
  insert into public.system_configuration_backups(created_by,payload) values(auth.uid(),snapshot) returning id into backup_id;
  insert into public.system_maintenance_audit(actor_id,action,details) values(auth.uid(),'configuration_backed_up',jsonb_build_object('backup_id',backup_id));
  return backup_id;
end $$;

create function public.restore_system_configuration_backup(p_backup_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare snapshot jsonb; item jsonb; safety_backup uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may restore configuration' using errcode='42501'; end if;
  select payload into snapshot from public.system_configuration_backups where id=p_backup_id;
  if snapshot is null then raise exception 'Backup not found'; end if;
  lock table public.dormitory_options in share row exclusive mode;
  safety_backup:=public.create_system_configuration_backup();
  for item in select value from jsonb_array_elements(snapshot->'options') loop
    if not exists(select 1 from public.dormitory_options where id=(item->>'id')::uuid
      and not is_system and group_key=item->>'group_key' and code=item->>'code'
      and category_code is not distinct from item->>'category_code') then
      raise exception 'Configuration identity changed; restore aborted'; end if;
    update public.dormitory_options set label=item->>'label',is_active=(item->>'is_active')::boolean,
      sort_order=(item->>'sort_order')::integer,instructions=coalesce(item->>'instructions','')
      where id=(item->>'id')::uuid;
  end loop;
  insert into public.system_maintenance_audit(actor_id,action,details) values(auth.uid(),'configuration_restored',
    jsonb_build_object('backup_id',p_backup_id,'safety_backup_id',safety_backup));
end $$;
revoke all on function public.set_system_maintenance(boolean,text,timestamptz),
  public.create_system_configuration_backup(),public.restore_system_configuration_backup(uuid) from public,anon;
grant execute on function public.set_system_maintenance(boolean,text,timestamptz),
  public.create_system_configuration_backup(),public.restore_system_configuration_backup(uuid) to authenticated;
commit;
