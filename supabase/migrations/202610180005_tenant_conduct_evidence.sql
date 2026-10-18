begin;
create table public.tenant_conduct_submissions (
  id uuid primary key,
  case_id uuid not null references public.conduct_cases(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id),
  kind text not null check(kind in ('response','appeal')),
  statement text not null,
  supporting_information text not null default '',
  attachments jsonb not null,
  response_id uuid unique references public.conduct_case_responses(id) on delete restrict,
  appeal_id uuid unique references public.conduct_case_appeals(id) on delete restrict,
  created_at timestamptz not null default now(),
  check((kind='response' and response_id is not null and appeal_id is null) or
    (kind='appeal' and appeal_id is not null and response_id is null))
);
create table public.tenant_conduct_evidence (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.tenant_conduct_submissions(id) on delete restrict,
  case_id uuid not null references public.conduct_cases(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id),
  storage_path text not null unique,
  original_name text not null check(length(original_name) between 1 and 200),
  content_type text not null check(content_type in ('image/jpeg','image/png','image/webp')),
  size_bytes bigint not null check(size_bytes between 1 and 5242880),
  caption text not null default '' check(length(caption)<=1000),
  created_at timestamptz not null default now()
);
create index tenant_conduct_evidence_case on public.tenant_conduct_evidence(case_id,created_at);
alter table public.tenant_conduct_submissions enable row level security;
alter table public.tenant_conduct_evidence enable row level security;
revoke all on public.tenant_conduct_submissions,public.tenant_conduct_evidence from anon,authenticated,service_role;
grant select on public.tenant_conduct_submissions,public.tenant_conduct_evidence to authenticated,service_role;
create function public.can_read_tenant_conduct_material(p_case_id uuid,p_tenant_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
select auth.uid() is not null and (public.is_staff() or (p_tenant_id=auth.uid()
  and public.current_user_role()::text='tenant' and exists(select 1 from public.conduct_cases c
    where c.id=p_case_id and c.tenant_id=auth.uid() and c.tenant_notified_at is not null)));
$$;
create policy tenant_conduct_submission_read on public.tenant_conduct_submissions for select to authenticated
using(public.can_read_tenant_conduct_material(case_id,tenant_id));
create policy tenant_conduct_evidence_read on public.tenant_conduct_evidence for select to authenticated
using(public.can_read_tenant_conduct_material(case_id,tenant_id));
create function public.protect_tenant_conduct_history() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Submitted tenant evidence and responses cannot be edited or deleted'; end $$;
create trigger tenant_conduct_submission_immutable before update or delete on public.tenant_conduct_submissions
for each row execute function public.protect_tenant_conduct_history();
create trigger tenant_conduct_evidence_immutable before update or delete on public.tenant_conduct_evidence
for each row execute function public.protect_tenant_conduct_history();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('tenant-conduct-evidence','tenant-conduct-evidence',false,5242880,array['image/jpeg','image/png','image/webp']);
create function public.can_upload_tenant_conduct_evidence(p_path text) returns boolean
language sql stable security definer set search_path='' as $$
select auth.uid() is not null and public.current_user_role()::text='tenant'
  and split_part(p_path,'/',1)=auth.uid()::text
  and p_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$'
  and exists(select 1 from public.conduct_cases c where c.id::text=split_part(p_path,'/',2)
    and c.tenant_id=auth.uid() and c.tenant_notified_at is not null
    and c.status in ('awaiting_response','under_review','warning_issued','resolved','termination_review_recommended'))
  and not exists(select 1 from public.tenant_conduct_submissions s where s.id::text=split_part(p_path,'/',3));
$$;
create policy tenant_conduct_photo_upload on storage.objects for insert to authenticated
with check(bucket_id='tenant-conduct-evidence' and public.can_upload_tenant_conduct_evidence(name));
create function public.can_cleanup_tenant_conduct_evidence(p_path text,p_owner text) returns boolean
language sql stable security definer set search_path='' as $$
select auth.uid() is not null and p_owner=auth.uid()::text and split_part(p_path,'/',1)=auth.uid()::text
  and not exists(select 1 from public.tenant_conduct_evidence e where e.storage_path=p_path);
$$;
create policy tenant_conduct_photo_read on storage.objects for select to authenticated
using(bucket_id='tenant-conduct-evidence' and (public.can_cleanup_tenant_conduct_evidence(name,owner_id)
  or exists(select 1 from public.tenant_conduct_evidence e where e.storage_path=name)));
create policy tenant_conduct_detached_cleanup on storage.objects for delete to authenticated
using(bucket_id='tenant-conduct-evidence' and public.can_cleanup_tenant_conduct_evidence(name,owner_id));
create function public.protect_tenant_conduct_object() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.tenant_conduct_evidence e
    where old.bucket_id='tenant-conduct-evidence' and e.storage_path=old.name) then
    raise exception 'Registered tenant evidence cannot be replaced or deleted';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
create trigger protect_tenant_conduct_object before update or delete on storage.objects
for each row execute function public.protect_tenant_conduct_object();

create function public.submit_tenant_conduct_material(p_id uuid,p_case_id uuid,p_kind text,
  p_statement text,p_support text default '',p_attachments jsonb default '[]')
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.conduct_cases; saved public.tenant_conduct_submissions; item jsonb; obj storage.objects;
  result_id uuid; response uuid; appeal uuid; path text; mime text; bytes bigint;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'tenant' then raise exception 'Tenant access required' using errcode='42501'; end if;
  select * into c from public.conduct_cases where id=p_case_id for update;
  if not found or c.tenant_id<>auth.uid() or c.tenant_notified_at is null then raise exception 'This case is not available to your account' using errcode='42501'; end if;
  select * into saved from public.tenant_conduct_submissions where id=p_id;
  if found then
    if saved.case_id=p_case_id and saved.tenant_id=auth.uid() and saved.kind=p_kind
      and saved.statement=btrim(p_statement) and saved.supporting_information=btrim(coalesce(p_support,''))
      and saved.attachments=p_attachments then return coalesce(saved.response_id,saved.appeal_id); end if;
    raise exception 'This request was already used for different submission details';
  end if;
  if p_id is null or p_kind is null or p_kind not in ('response','appeal') then raise exception 'Invalid submission request'; end if;
  if p_attachments is null or jsonb_typeof(p_attachments)<>'array' then raise exception 'Invalid attachments'; end if;
  if jsonb_array_length(p_attachments)>5 then raise exception 'Attach at most five photos'; end if;
  if p_kind='response' and btrim(coalesce(p_support,''))<>'' then raise exception 'Response supporting information must be included in its statement'; end if;
  -- Validate every actual stored object before creating the response or appeal.
  for item in select value from jsonb_array_elements(p_attachments) loop
    path:=item->>'storage_path'; mime:=item->>'content_type';
    if path is null or path not like auth.uid()::text||'/'||p_case_id::text||'/'||p_id::text||'/%'
      or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|png|webp)$' then raise exception 'Invalid evidence path'; end if;
    select * into obj from storage.objects where bucket_id='tenant-conduct-evidence' and name=path for update;
    if not found or obj.owner_id is distinct from auth.uid()::text then raise exception 'Upload your evidence photo before submitting'; end if;
    bytes:=(obj.metadata->>'size')::bigint;
    if mime is null or mime not in ('image/jpeg','image/png','image/webp') or obj.metadata->>'mimetype' is distinct from mime
      or bytes is null or bytes not between 1 and 5242880 or (item->>'size_bytes')::bigint is distinct from bytes
      or length(coalesce(item->>'original_name','')) not between 1 and 200
      or length(coalesce(item->>'caption',''))>1000 then raise exception 'Invalid evidence photo metadata'; end if;
  end loop;
  if p_kind='response' then response:=public.submit_conduct_case_response(p_case_id,p_statement); result_id:=response;
  else appeal:=public.submit_conduct_case_appeal(p_case_id,p_statement,p_support); result_id:=appeal; end if;
  insert into public.tenant_conduct_submissions(id,case_id,tenant_id,kind,statement,supporting_information,attachments,response_id,appeal_id)
    values(p_id,p_case_id,auth.uid(),p_kind,btrim(p_statement),btrim(coalesce(p_support,'')),p_attachments,response,appeal);
  for item in select value from jsonb_array_elements(p_attachments) loop
    insert into public.tenant_conduct_evidence(submission_id,case_id,tenant_id,storage_path,original_name,content_type,size_bytes,caption)
      values(p_id,p_case_id,auth.uid(),item->>'storage_path',item->>'original_name',item->>'content_type',
        (item->>'size_bytes')::bigint,coalesce(item->>'caption',''));
  end loop;
  -- Response events already emit the saved conduct notification. Avoid a second
  -- alert for the same submission; appeals have no creation event producer.
  if p_kind='appeal' then
  perform public.emit_staff_notification('safety','Conduct appeal submitted',
    'A tenant submitted '||case when jsonb_array_length(p_attachments)>0 then 'a statement with evidence photos.' else 'a statement.' end,
    'conduct_case',p_case_id,jsonb_build_object('submission_id',p_id,'case_id',p_case_id),
    'tenant-conduct-submission:'||p_id::text,0);
  end if;
  return result_id;
end $$;
revoke all on function public.protect_tenant_conduct_history(),public.protect_tenant_conduct_object() from public,anon,authenticated,service_role;
revoke all on function public.can_cleanup_tenant_conduct_evidence(text,text),public.can_read_tenant_conduct_material(uuid,uuid),public.can_upload_tenant_conduct_evidence(text),public.submit_tenant_conduct_material(uuid,uuid,text,text,text,jsonb) from public,anon,service_role;
grant execute on function public.can_cleanup_tenant_conduct_evidence(text,text),public.can_read_tenant_conduct_material(uuid,uuid),public.can_upload_tenant_conduct_evidence(text),public.submit_tenant_conduct_material(uuid,uuid,text,text,text,jsonb) to authenticated;
alter publication supabase_realtime add table public.tenant_conduct_evidence;
notify pgrst,'reload schema';
commit;
