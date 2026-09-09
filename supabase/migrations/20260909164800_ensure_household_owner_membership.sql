create or replace function public.add_household_owner_membership()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.household_members (household_id, user_id, role, status)
  values (new.id, new.owner_user_id, 'owner', 'active')
  on conflict (household_id, user_id) do update
    set role = 'owner', status = 'active', updated_at = now();
  return new;
end;
$$;

revoke all on function public.add_household_owner_membership() from public;
revoke all on function public.add_household_owner_membership() from anon;
grant execute on function public.add_household_owner_membership() to authenticated;
grant execute on function public.add_household_owner_membership() to service_role;

drop trigger if exists households_auto_add_owner on public.households;
create trigger households_auto_add_owner
after insert on public.households
for each row execute function public.add_household_owner_membership();
