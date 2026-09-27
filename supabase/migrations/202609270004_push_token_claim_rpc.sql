begin;

-- A Firebase registration token identifies an app installation, not an
-- account. If a person signs out and another account signs in on the same
-- phone, the token may still exist under the previous user. A normal upsert
-- cannot transfer that row because RLS correctly prevents users from updating
-- another user's data. This narrowly scoped RPC performs the transfer after
-- authenticating the caller; FCM tokens are high-entropy bearer identifiers.
create or replace function public.register_current_push_device(
  p_fcm_token text,
  p_platform text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text := trim(p_fcm_token);
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if char_length(v_token) < 20 or char_length(v_token) > 4096 then
    raise exception 'Invalid push token';
  end if;
  if p_platform not in ('android', 'ios') then
    raise exception 'Invalid push platform';
  end if;

  insert into public.push_device_tokens (
    user_id, fcm_token, platform, last_seen_at, revoked_at
  ) values (
    v_user_id, v_token, p_platform, now(), null
  )
  on conflict (fcm_token) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      last_seen_at = excluded.last_seen_at,
      revoked_at = null;
end;
$$;

revoke all on function public.register_current_push_device(text, text)
  from public, anon;
grant execute on function public.register_current_push_device(text, text)
  to authenticated;

commit;
