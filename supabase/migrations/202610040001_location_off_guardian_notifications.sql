-- Notify linked guardians on the next monitoring-alert run, before escalation.
alter table public.location_monitoring_incidents
  add column guardian_notified_at timestamptz;

-- Existing escalations already notified guardians; do not repeat their initial alert.
update public.location_monitoring_incidents
set guardian_notified_at = escalated_at
where escalated_at is not null;

create index location_monitoring_pending_guardian_notification
  on public.location_monitoring_incidents (started_at)
  where recovered_at is null and guardian_notified_at is null;

comment on column public.location_monitoring_incidents.guardian_notified_at is
  'Initial location-off notification processed for this tenant''s linked guardians.';
