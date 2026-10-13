-- Disable matching Phase 3 UI first. Only removes display functions/signals; never history.
begin;
drop trigger room_contract_display_changed on public.tenant_contracts;
drop trigger room_occupancy_display_changed on public.contract_occupancy_arrangements;
drop function public.refresh_room_contract_display();
drop function public.get_room_contract_occupancies(uuid,boolean);
commit;
