-- Add retry safety to the existing Owner-approved charge API; retain legacy APIs.
begin;
alter table public.billing_charges add column additional_request_id uuid;
create unique index billing_additional_request on public.billing_charges(created_by,additional_request_id)
  where additional_request_id is not null;
create function public.create_additional_charge(
  p_tenant_id uuid,p_title text,p_category text,p_amount numeric,p_due_date date,
  p_notes text,p_reason text,p_specific_category text,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare c public.billing_charges; result jsonb;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Owner access required' using errcode='42501'; end if;
  if p_request_id is null then raise exception 'Charge request identifier required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('additional-charge:'||auth.uid()::text||':'||p_request_id::text,0));
  select * into c from public.billing_charges
    where created_by=auth.uid() and additional_request_id=p_request_id;
  if found then
    if c.tenant_id is distinct from p_tenant_id or c.title is distinct from btrim(p_title)
      or c.category is distinct from lower(btrim(p_category)) or c.original_amount is distinct from p_amount
      or c.due_date is distinct from p_due_date or c.notes is distinct from nullif(btrim(coalesce(p_notes,'')),'')
      or c.terms_snapshot->>'manual_approval_reason' is distinct from btrim(p_reason)
      or c.terms_snapshot->>'specific_category' is distinct from nullif(btrim(p_specific_category),'') then
      raise exception 'Charge request already used with different details'; end if;
    select to_jsonb(s) into result from public.billing_charge_summaries s where id=c.id;
    return result||jsonb_build_object('charge_created',false);
  end if;
  -- Keep the existing validations, categories, reason and approval audit snapshot.
  result:=public.create_additional_charge(p_tenant_id,p_title,p_category,p_amount,p_due_date,p_notes,p_reason,p_specific_category);
  update public.billing_charges set additional_request_id=p_request_id where id=(result->>'id')::uuid;
  return result||jsonb_build_object('charge_created',true);
end $$;
revoke all on function public.create_additional_charge(uuid,text,text,numeric,date,text,text,text,uuid) from public,anon;
grant execute on function public.create_additional_charge(uuid,text,text,numeric,date,text,text,text,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
