alter table public.tenant_details add column residency_status text not null default 'active'
check (residency_status in ('active', 'moving_out', 'inactive'));

create or replace function public.assign_tenant_bed(p_tenant_id uuid, p_bed_space_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  perform 1 from public.bed_spaces where id = p_bed_space_id and status = 'available' for update;
  if not found then raise exception 'The selected bed is no longer available'; end if;
  update public.tenant_assignments set status = 'ended', ends_on = current_date
    where tenant_id = p_tenant_id and status = 'active';
  insert into public.tenant_assignments (tenant_id, bed_space_id) values (p_tenant_id, p_bed_space_id);
  update public.tenant_details set residency_status = 'active' where profile_id = p_tenant_id;
end; $$;

create or replace function public.end_tenant_assignment(p_tenant_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  update public.tenant_assignments set status = 'ended', ends_on = current_date
    where tenant_id = p_tenant_id and status = 'active';
end; $$;

revoke all on function public.assign_tenant_bed(uuid, uuid) from public, anon;
revoke all on function public.end_tenant_assignment(uuid) from public, anon;
grant execute on function public.assign_tenant_bed(uuid, uuid) to authenticated;
grant execute on function public.end_tenant_assignment(uuid) to authenticated;
