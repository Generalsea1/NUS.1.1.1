drop policy if exists household_member_select_self on public.household_members;
drop policy if exists household_member_select_same_household on public.household_members;

create policy household_member_select_same_household
on public.household_members
for select
to authenticated
using (public.is_active_household_member(household_id));
