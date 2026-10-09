-- QA repair: remove anonymous gate-history exposure and restore the missing
-- boundary editor RPC without changing stored records or boundary geometry.
begin;
drop policy if exists "Allow anon to read gate_events" on public.gate_events;
revoke all on public.gate_events from anon;
create or replace function public.update_dorm_boundary_config(
  p_center_lat double precision default null,
  p_center_lng double precision default null,
  p_radius_meters double precision default null,
  p_edge_buffer_meters double precision default null,
  p_boundary_mode text default null,
  p_polygon_points text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_role text;
  v_active_id uuid;
  v_parsed_polygon jsonb;
begin
  -- 1. Authorization: Only owner or staff can update boundary configuration
  select role::text into v_caller_role
  from public.profiles
  where id = auth.uid();

  if v_caller_role is null or v_caller_role not in ('owner', 'caretaker') then
    raise exception 'Unauthorized: Only owner and staff can update dormitory boundaries.';
  end if;

  -- 2. Input validation
  if p_center_lat is not null and not (p_center_lat between -90 and 90) then
    raise exception 'Invalid latitude: must be between -90 and 90.';
  end if;

  if p_center_lng is not null and not (p_center_lng between -180 and 180) then
    raise exception 'Invalid longitude: must be between -180 and 180.';
  end if;

  if p_radius_meters is not null and (p_radius_meters <= 0 or p_radius_meters in ('NaN'::double precision,'Infinity'::double precision)) then
    raise exception 'Invalid radius: must be greater than 0 meters.';
  end if;

  if p_edge_buffer_meters is not null and (p_edge_buffer_meters < 0 or p_edge_buffer_meters in ('NaN'::double precision,'Infinity'::double precision)) then
    raise exception 'Invalid edge buffer: must be non-negative.';
  end if;

  if p_boundary_mode is not null and p_boundary_mode not in ('polygon', 'circle') then
    raise exception 'Invalid boundary mode: must be polygon or circle.';
  end if;

  if p_polygon_points is not null then
    begin
      v_parsed_polygon := p_polygon_points::jsonb;
    exception when others then
      raise exception 'Invalid polygon points: must be valid JSON array.';
    end;
    if jsonb_typeof(v_parsed_polygon) is distinct from 'array' then
      raise exception 'Polygon points must be a JSON array'; end if;
    if jsonb_array_length(v_parsed_polygon)<3 then
      raise exception 'Polygon needs at least three points'; end if;
    if exists(select 1 from jsonb_array_elements(v_parsed_polygon) p
      where jsonb_typeof(p->'lat') is distinct from 'number'
        or jsonb_typeof(p->'lng') is distinct from 'number') then
      raise exception 'Polygon points must contain numeric lat and lng'; end if;
    if exists(select 1 from jsonb_array_elements(v_parsed_polygon) p
      where not ((p->>'lat')::double precision between -90 and 90)
        or not ((p->>'lng')::double precision between -180 and 180)) then
      raise exception 'Polygon points must use valid latitude and longitude'; end if;
    if (select count(distinct ((p->>'lat')::double precision,(p->>'lng')::double precision))
        from jsonb_array_elements(v_parsed_polygon) p)<3 then
      raise exception 'Polygon needs three distinct points'; end if;
  end if;

  -- 3. Find active boundary row
  select id into v_active_id
  from public.dorm_boundary_config
  where is_active = true
  order by updated_at desc
  limit 1 for update;

  if v_active_id is null then
    -- Insert a new active row
    insert into public.dorm_boundary_config (
      boundary_name,
      boundary_mode,
      center_latitude,
      center_longitude,
      radius_meters,
      edge_buffer_meters,
      polygon_points,
      is_active,
      updated_at
    ) values (
      'Carmelita Dormitory Main Lot',
      coalesce(p_boundary_mode, 'polygon'),
      coalesce(p_center_lat, 14.949402),
      coalesce(p_center_lng, 120.884676),
      coalesce(p_radius_meters, 50.0),
      coalesce(p_edge_buffer_meters, 3.0),
      coalesce(v_parsed_polygon, '[
        {"lat": 14.949435124962447, "lng": 120.88489213696135},
        {"lat": 14.949251893796628, "lng": 120.88482211758398},
        {"lat": 14.949350151678374, "lng": 120.88452020740704},
        {"lat": 14.949547385390431, "lng": 120.88454200910613}
      ]'::jsonb),
      true,
      now()
    ) returning id into v_active_id;
  else
    -- Update existing active row
    update public.dorm_boundary_config
    set
      center_latitude = coalesce(p_center_lat, center_latitude),
      center_longitude = coalesce(p_center_lng, center_longitude),
      radius_meters = coalesce(p_radius_meters, radius_meters),
      edge_buffer_meters = coalesce(p_edge_buffer_meters, edge_buffer_meters),
      boundary_mode = coalesce(p_boundary_mode, boundary_mode),
      polygon_points = coalesce(v_parsed_polygon, polygon_points),
      config_version = config_version + 1,
      updated_at = now()
    where id = v_active_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'boundary_id', v_active_id,
    'updated_at', now()
  );
end;
$$;

revoke all on function public.update_dorm_boundary_config(double precision,double precision,double precision,double precision,text,text) from public,anon;
grant execute on function public.update_dorm_boundary_config(double precision,double precision,double precision,double precision,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
