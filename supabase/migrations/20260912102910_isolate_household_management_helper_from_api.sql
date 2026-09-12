create schema if not exists private;

create or replace function private.can_manage_household(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog
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

revoke all on function public.can_manage_household(uuid) from public, anon, authenticated, service_role;
revoke all on function private.can_manage_household(uuid) from public, anon;
grant usage on schema private to authenticated, service_role;
grant execute on function private.can_manage_household(uuid) to authenticated, service_role;

alter policy household_member_update_admin on public.household_members
  using (
    private.can_manage_household(household_id)
    and user_id <> (
      select h.owner_user_id from public.households h where h.id = household_members.household_id
    )
  );

drop function if exists public.can_manage_household(uuid);
