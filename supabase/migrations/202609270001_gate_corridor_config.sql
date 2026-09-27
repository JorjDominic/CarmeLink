-- Adds an explicitly configured official entrance to the device-owned
-- polygon verifier. Tenant coordinates are never stored in this table.
alter table public.dorm_boundary_config
  add column if not exists gate_enabled boolean not null default true,
  add column if not exists gate_start_latitude double precision default 14.949435124962447,
  add column if not exists gate_start_longitude double precision default 120.88489213696135,
  add column if not exists gate_end_latitude double precision default 14.949251893796628,
  add column if not exists gate_end_longitude double precision default 120.88482211758398,
  add column if not exists gate_tolerance_meters double precision not null default 15.0,
  add column if not exists config_version bigint not null default 1;

alter table public.dorm_boundary_config
  alter column gate_enabled set default true,
  alter column gate_start_latitude set default 14.949435124962447,
  alter column gate_start_longitude set default 120.88489213696135,
  alter column gate_end_latitude set default 14.949251893796628,
  alter column gate_end_longitude set default 120.88482211758398;

alter table public.dorm_boundary_config
  drop constraint if exists dorm_boundary_gate_configuration_check;

alter table public.dorm_boundary_config
  add constraint dorm_boundary_gate_configuration_check check (
    gate_tolerance_meters between 3 and 50
    and (
      gate_enabled = false
      or (
        gate_start_latitude between -90 and 90
        and gate_end_latitude between -90 and 90
        and gate_start_longitude between -180 and 180
        and gate_end_longitude between -180 and 180
        and (gate_start_latitude, gate_start_longitude)
          is distinct from
            (gate_end_latitude, gate_end_longitude)
      )
    )
  );

create or replace function public.update_dorm_gate_config(
  p_enabled boolean,
  p_start_lat double precision default null,
  p_start_lng double precision default null,
  p_end_lat double precision default null,
  p_end_lng double precision default null,
  p_tolerance_meters double precision default 15.0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_id uuid;
begin
  if p_enabled is null then
    raise exception 'Gate enabled state is required.';
  end if;
  if p_tolerance_meters is null then
    raise exception 'Gate tolerance is required.';
  end if;

  select role into v_role from public.profiles where id = auth.uid();
  if v_role is null or v_role not in ('owner', 'caretaker', 'staff', 'admin') then
    raise exception 'Unauthorized: Only owner and staff can update the gate corridor.';
  end if;
  if p_tolerance_meters < 3 or p_tolerance_meters > 50 then
    raise exception 'Gate tolerance must be between 3 and 50 metres.';
  end if;
  if p_enabled and (
    p_start_lat is null or p_start_lng is null or
    p_end_lat is null or p_end_lng is null
  ) then
    raise exception 'Both gate endpoints are required when the gate is enabled.';
  end if;

  select id into v_id
    from public.dorm_boundary_config
   where is_active = true
   order by updated_at desc
   limit 1;

  if v_id is null then
    raise exception 'No active dormitory boundary exists.';
  end if;

  update public.dorm_boundary_config
     set gate_enabled = p_enabled,
         gate_start_latitude = p_start_lat,
         gate_start_longitude = p_start_lng,
         gate_end_latitude = p_end_lat,
         gate_end_longitude = p_end_lng,
         gate_tolerance_meters = p_tolerance_meters,
         config_version = config_version + 1,
         updated_at = now()
   where id = v_id;

  return jsonb_build_object('success', true, 'boundary_id', v_id);
end;
$$;

revoke all on function public.update_dorm_gate_config(
  boolean, double precision, double precision, double precision,
  double precision, double precision
) from public, anon;
grant execute on function public.update_dorm_gate_config(
  boolean, double precision, double precision, double precision,
  double precision, double precision
) to authenticated;
