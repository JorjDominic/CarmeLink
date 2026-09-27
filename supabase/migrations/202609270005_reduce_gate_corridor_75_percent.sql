-- Reduce the official gate corridor by 75% while preserving its midpoint and
-- orientation. The remaining corridor is the centered 25% of the previously
-- configured Point 1 to Point 2 segment, with one-quarter of its tolerance.
alter table public.dorm_boundary_config
  alter column gate_start_latitude set default 14.949366413275264,
  alter column gate_start_longitude set default 120.88486587969484,
  alter column gate_end_latitude set default 14.94932060548381,
  alter column gate_end_longitude set default 120.88484837485049,
  alter column gate_tolerance_meters set default 3.75;

update public.dorm_boundary_config
set gate_start_latitude = gate_start_latitude
      + (gate_end_latitude - gate_start_latitude) * 0.375,
    gate_start_longitude = gate_start_longitude
      + (gate_end_longitude - gate_start_longitude) * 0.375,
    gate_end_latitude = gate_start_latitude
      + (gate_end_latitude - gate_start_latitude) * 0.625,
    gate_end_longitude = gate_start_longitude
      + (gate_end_longitude - gate_start_longitude) * 0.625,
    gate_tolerance_meters = greatest(3.0, gate_tolerance_meters * 0.25),
    config_version = config_version + 1,
    updated_at = now()
where is_active = true
  and gate_enabled = true;
