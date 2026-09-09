revoke execute on function public.accept_household_invitation(text) from public;
revoke execute on function public.accept_household_invitation(text) from anon;
grant execute on function public.accept_household_invitation(text) to authenticated;
grant all on function public.accept_household_invitation(text) to service_role;
