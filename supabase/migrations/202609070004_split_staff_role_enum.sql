-- Preserve the existing owner account while replacing the combined role.
alter type public.app_role rename value 'owner_caretaker' to 'owner';
alter type public.app_role add value 'caretaker' after 'guardian';
