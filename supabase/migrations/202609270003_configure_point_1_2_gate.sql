-- Configure the official gate as the property edge from polygon Point 1 to
-- Point 2. This forward migration also updates databases where the gate
-- configuration migration was already applied with the gate disabled.
update public.dorm_boundary_config
set gate_enabled = true,
    gate_start_latitude = 14.949435124962447,
    gate_start_longitude = 120.88489213696135,
    gate_end_latitude = 14.949251893796628,
    gate_end_longitude = 120.88482211758398,
    gate_tolerance_meters = 15.0,
    config_version = config_version + 1,
    updated_at = now()
where id = (
  select id
  from public.dorm_boundary_config
  where is_active = true
  order by updated_at desc
  limit 1
);
