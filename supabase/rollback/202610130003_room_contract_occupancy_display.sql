-- Disable matching Phase 3 UI first; never remove occupancy history.
begin;
drop function public.get_room_contract_occupancies(uuid,boolean);
commit;
