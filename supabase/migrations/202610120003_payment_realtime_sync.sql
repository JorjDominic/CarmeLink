begin;
-- Adjustments change summary balances without modifying billing_charges.
-- Publish these RLS-protected tables so all payment workspaces refresh promptly.
do $$
declare v_table text;
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach v_table in array array['billing_charge_actions','paymongo_payment_sessions'] loop
      if not exists(select 1 from pg_publication_tables
        where pubname='supabase_realtime' and schemaname='public' and tablename=v_table) then
        execute format('alter publication supabase_realtime add table public.%I',v_table);
      end if;
    end loop;
  end if;
end $$;
commit;
