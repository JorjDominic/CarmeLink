begin;

alter table public.confidential_report_addenda
  add column if not exists client_request_id text;

update public.confidential_report_addenda
set client_request_id = gen_random_uuid()::text
where client_request_id is null;

alter table public.confidential_report_addenda
  alter column client_request_id set not null;

create unique index if not exists confidential_report_addenda_request_key
  on public.confidential_report_addenda(author_id, client_request_id);

create or replace function public.append_confidential_report_addendum(
  p_report_id uuid,
  p_body text,
  p_request_id text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_body text := btrim(coalesce(p_body, ''));
  v_request_id text := btrim(coalesce(p_request_id, ''));
  v_existing public.confidential_report_addenda;
  v_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if char_length(v_body) < 5 or char_length(v_body) > 2000 then
    raise exception 'Use 5 to 2000 characters';
  end if;

  if char_length(v_request_id) < 8 or char_length(v_request_id) > 120 then
    raise exception 'Invalid correction request identifier';
  end if;

  if not (
    coalesce(public.is_staff(), false)
    or exists (
      select 1
      from public.confidential_reports r
      where r.id = p_report_id
        and r.tenant_id = v_user_id
    )
  ) then
    raise exception 'Report access denied';
  end if;

  select *
  into v_existing
  from public.confidential_report_addenda a
  where a.author_id = v_user_id
    and a.client_request_id = v_request_id;

  if found then
    if v_existing.report_id <> p_report_id or v_existing.body <> v_body then
      raise exception 'Correction request identifier conflict';
    end if;
    return v_existing.id;
  end if;

  begin
    insert into public.confidential_report_addenda(
      report_id,
      author_id,
      body,
      client_request_id
    ) values (
      p_report_id,
      v_user_id,
      v_body,
      v_request_id
    )
    returning id into v_id;
  exception
    when unique_violation then
      select id
      into v_id
      from public.confidential_report_addenda a
      where a.author_id = v_user_id
        and a.client_request_id = v_request_id
        and a.report_id = p_report_id
        and a.body = v_body;

      if v_id is null then
        raise;
      end if;
  end;

  return v_id;
end;
$$;

revoke all on function public.append_confidential_report_addendum(uuid, text, text)
  from public, anon;
grant execute on function public.append_confidential_report_addendum(uuid, text, text)
  to authenticated;

commit;
