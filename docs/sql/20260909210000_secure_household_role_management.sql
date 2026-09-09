-- NUS household role management.
-- Authorization is enforced by RLS; the owner row can never be modified by this policy.

create or replace function public.can_manage_household(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = (select auth.uid())
      and hm.status = 'active'
      and hm.role in ('owner', 'admin')
  );
$$;

revoke all on function public.can_manage_household(uuid) from public;
grant execute on function public.can_manage_household(uuid) to authenticated;

drop policy if exists household_member_update_admin on public.household_members;
create policy household_member_update_admin
on public.household_members
for update
to authenticated
using (
  public.can_manage_household(household_id)
  and user_id <> (
    select h.owner_user_id
    from public.households h
    where h.id = household_id
  )
)
with check (
  role in ('admin', 'member')
  and status = 'active'
  and user_id <> (
    select h.owner_user_id
    from public.households h
    where h.id = household_id
  )
);
