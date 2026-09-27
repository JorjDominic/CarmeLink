-- Repair only missing/invalid legacy polygon rows. Valid owner-configured
-- polygons (three or more perimeter-ordered points) are left untouched.
update public.dorm_boundary_config
set polygon_points = '[
      {"lat": 14.949435124962447, "lng": 120.88489213696135},
      {"lat": 14.949251893796628, "lng": 120.88482211758398},
      {"lat": 14.949350151678374, "lng": 120.88452020740704},
      {"lat": 14.949547385390431, "lng": 120.88454200910613}
    ]'::jsonb,
    updated_at = now()
where polygon_points is null
   or case
        when jsonb_typeof(polygon_points) = 'array'
          then jsonb_array_length(polygon_points) < 3
        else true
      end;

alter table public.dorm_boundary_config
  drop constraint if exists dorm_boundary_polygon_shape_check;

alter table public.dorm_boundary_config
  add constraint dorm_boundary_polygon_shape_check check (
    case
      when jsonb_typeof(polygon_points) = 'array'
        then jsonb_array_length(polygon_points) >= 3
      else false
    end
  );
