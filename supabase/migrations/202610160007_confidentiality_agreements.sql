-- Infrastructure only: deliberately no legal wording, seeded version or account gate.
begin;
create table public.confidentiality_agreement_versions (
  id uuid primary key default gen_random_uuid(),
  audience text not null check(audience in ('tenant','guardian')),
  version text not null check(char_length(btrim(version)) between 1 and 80),
  content text not null check(char_length(btrim(content)) between 20 and 100000),
  published_by uuid not null references public.profiles(id) on delete restrict,
  published_at timestamptz not null default clock_timestamp(),
  unique(audience,version)
);
create table public.confidentiality_agreement_acceptances (
  id uuid primary key default gen_random_uuid(),
  agreement_id uuid not null references public.confidentiality_agreement_versions(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  accepted_at timestamptz not null default clock_timestamp(),
  unique(user_id,agreement_id)
);
create index confidentiality_version_latest on public.confidentiality_agreement_versions(audience,published_at desc,id desc);
alter table public.confidentiality_agreement_versions enable row level security;
alter table public.confidentiality_agreement_acceptances enable row level security;
revoke all on public.confidentiality_agreement_versions,public.confidentiality_agreement_acceptances from anon,authenticated;
grant select on public.confidentiality_agreement_versions,public.confidentiality_agreement_acceptances to authenticated;
create policy confidentiality_versions_read on public.confidentiality_agreement_versions for select to authenticated
  using(public.current_user_role()::text='owner' or audience=public.current_user_role()::text);
create policy confidentiality_acceptances_read on public.confidentiality_agreement_acceptances for select to authenticated
  using(public.current_user_role()::text='owner' or user_id=auth.uid());
create function public.protect_confidentiality_history() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'Published agreements and acceptance records are immutable' using errcode='42501'; end $$;
revoke all on function public.protect_confidentiality_history() from public,anon,authenticated;
create trigger confidentiality_versions_immutable before update or delete on public.confidentiality_agreement_versions
  for each row execute function public.protect_confidentiality_history();
create trigger confidentiality_acceptances_immutable before update or delete on public.confidentiality_agreement_acceptances
  for each row execute function public.protect_confidentiality_history();

create function public.publish_confidentiality_agreement(p_audience text,p_version text,p_content text,p_approved boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.confidentiality_agreement_versions;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may publish approved agreements' using errcode='42501'; end if;
  if p_approved is distinct from true then raise exception 'Confirm that this is approved agreement wording'; end if;
  if p_audience is null or p_audience not in ('tenant','guardian') or char_length(btrim(coalesce(p_version,''))) not between 1 and 80
    or char_length(btrim(coalesce(p_content,''))) not between 20 and 100000 then
    raise exception 'Valid audience, version and approved content are required'; end if;
  -- Serialize publication/acceptance for each audience, including the first version.
  perform pg_advisory_xact_lock(hashtextextended('confidentiality:'||p_audience,0));
  select * into v from public.confidentiality_agreement_versions where audience=p_audience and version=btrim(p_version);
  if found then
    if v.content is distinct from p_content or v.published_by is distinct from auth.uid() then
      raise exception 'This agreement version already exists with different content or publisher'; end if;
    return v.id;
  end if;
  insert into public.confidentiality_agreement_versions(audience,version,content,published_by)
    values(p_audience,btrim(p_version),p_content,auth.uid()) returning * into v;
  return v.id;
end $$;

create function public.accept_confidentiality_agreement(p_agreement_id uuid,p_reviewed boolean,p_accepted boolean)
returns uuid language plpgsql security definer set search_path='' as $$
declare v public.confidentiality_agreement_versions; a public.confidentiality_agreement_acceptances;
  role_name text:=public.current_user_role()::text; latest uuid;
begin
  if auth.uid() is null or coalesce(role_name,'') not in ('tenant','guardian') then
    raise exception 'Only tenants and guardians may accept their own agreements' using errcode='42501'; end if;
  if p_reviewed is distinct from true or p_accepted is distinct from true then
    raise exception 'Review the complete agreement and explicitly accept it'; end if;
  perform pg_advisory_xact_lock(hashtextextended('confidentiality:'||role_name,0));
  select * into v from public.confidentiality_agreement_versions where id=p_agreement_id and audience=role_name;
  if not found then raise exception 'Agreement is not available to your account' using errcode='42501'; end if;
  select * into a from public.confidentiality_agreement_acceptances where agreement_id=v.id and user_id=auth.uid();
  if found then return a.id; end if;
  select id into latest from public.confidentiality_agreement_versions where audience=role_name
    order by published_at desc,id desc limit 1;
  if latest is distinct from v.id then raise exception 'A newer agreement is available. Refresh and review it first'; end if;
  insert into public.confidentiality_agreement_acceptances(agreement_id,user_id)
    values(v.id,auth.uid()) returning * into a;
  return a.id;
end $$;
revoke all on function public.publish_confidentiality_agreement(text,text,text,boolean),
  public.accept_confidentiality_agreement(uuid,boolean,boolean) from public,anon;
grant execute on function public.publish_confidentiality_agreement(text,text,text,boolean),
  public.accept_confidentiality_agreement(uuid,boolean,boolean) to authenticated;
commit;
