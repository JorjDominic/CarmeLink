-- Add inside_after_cutoff_enabled to guardian_alert_preferences and support inside alert preferences.

alter table public.guardian_alert_preferences
  add column if not exists inside_after_cutoff_enabled boolean not null default false;
-- Update get_my_guardian_alert_preferences
create or replace function public.get_my_guardian_alert_preferences()
returns public.guardian_alert_preferences
language plpgsql security definer set search_path = '' as $$
declare v_row public.guardian_alert_preferences;
begin
  if public.current_user_role() <> 'guardian' then
    raise exception 'Guardian access required';
  end if;
  insert into public.guardian_alert_preferences (guardian_id)
  values (auth.uid()) on conflict (guardian_id) do nothing;
  select * into v_row from public.guardian_alert_preferences
  where guardian_id = auth.uid();
  return v_row;
end $$;
-- Update update_my_guardian_alert_preferences with inside_after_cutoff_enabled support
create or replace function public.update_my_guardian_alert_preferences(
  p_gate_entry_enabled boolean,
  p_gate_exit_enabled boolean,
  p_outside_after_cutoff_enabled boolean,
  p_alert_cutoff time,
  p_inside_after_cutoff_enabled boolean default false
) returns public.guardian_alert_preferences
language plpgsql security definer set search_path = '' as $$
declare v_row public.guardian_alert_preferences;
begin
  if public.current_user_role() <> 'guardian' then
    raise exception 'Guardian access required';
  end if;
  if p_alert_cutoff is null then raise exception 'Alert cutoff is required'; end if;
  insert into public.guardian_alert_preferences (
    guardian_id, gate_entry_enabled, gate_exit_enabled,
    outside_after_cutoff_enabled, alert_cutoff, inside_after_cutoff_enabled, updated_at
  ) values (
    auth.uid(), coalesce(p_gate_entry_enabled, true),
    coalesce(p_gate_exit_enabled, true),
    coalesce(p_outside_after_cutoff_enabled, true), p_alert_cutoff,
    coalesce(p_inside_after_cutoff_enabled, false), now()
  ) on conflict (guardian_id) do update set
    gate_entry_enabled = excluded.gate_entry_enabled,
    gate_exit_enabled = excluded.gate_exit_enabled,
    outside_after_cutoff_enabled = excluded.outside_after_cutoff_enabled,
    inside_after_cutoff_enabled = excluded.inside_after_cutoff_enabled,
    alert_cutoff = excluded.alert_cutoff,
    updated_at = now()
  returning * into v_row;
  return v_row;
end $$;
revoke all on function public.update_my_guardian_alert_preferences(boolean,boolean,boolean,time,boolean) from public, anon;
grant execute on function public.update_my_guardian_alert_preferences(boolean,boolean,boolean,time,boolean) to authenticated;
