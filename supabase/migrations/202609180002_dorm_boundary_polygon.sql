-- Migration: 202609180002_dorm_boundary_polygon.sql
-- Adds dormitory boundary polygon definition and configuration table
-- maintaining zero-tenant-coordinate persistence rule.
-- Stores official perimeter geometry (polygon and fallback circular).

create table if not exists public.dorm_boundary_config (
  id uuid primary key default gen_random_uuid(),
  boundary_name text not null default 'Carmelita Dormitory Perimeter',
  boundary_mode text not null default 'polygon' check (boundary_mode in ('polygon', 'circle')),
  -- Circular boundary fallback
  center_latitude double precision not null default 14.949402,
  center_longitude double precision not null default 120.884676,
  radius_meters double precision not null default 50.0,
  edge_buffer_meters double precision not null default 3.0,
  -- Measured polygon coordinates as array of {lat, lng} JSON objects
  polygon_points jsonb not null default '[
    {"lat": 14.949435124962447, "lng": 120.88489213696135},
    {"lat": 14.949251893796628, "lng": 120.88482211758398},
    {"lat": 14.949350151678374, "lng": 120.88452020740704},
    {"lat": 14.949547385390431, "lng": 120.88454200910613}
  ]'::jsonb,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- Seed initial row if none exists
insert into public.dorm_boundary_config (
  boundary_name,
  boundary_mode,
  center_latitude,
  center_longitude,
  radius_meters,
  edge_buffer_meters,
  polygon_points,
  is_active
)
select
  'Carmelita Dormitory Main Lot',
  'polygon',
  14.949402,
  120.884676,
  50.0,
  3.0,
  '[
    {"lat": 14.949435124962447, "lng": 120.88489213696135},
    {"lat": 14.949251893796628, "lng": 120.88482211758398},
    {"lat": 14.949350151678374, "lng": 120.88452020740704},
    {"lat": 14.949547385390431, "lng": 120.88454200910613}
  ]'::jsonb,
  true
where not exists (select 1 from public.dorm_boundary_config);

-- Enable RLS
alter table public.dorm_boundary_config enable row level security;

-- All authenticated users can read boundary configuration
create policy "Authenticated users can read boundary configuration"
  on public.dorm_boundary_config
  for select
  to authenticated
  using (true);

-- Only owners and dorm managers can modify boundary config
create policy "Owners and dorm managers can modify boundary config"
  on public.dorm_boundary_config
  for all
  to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
      and role in ('owner', 'dorm_manager')
    )
  )
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
      and role in ('owner', 'dorm_manager')
    )
  );

