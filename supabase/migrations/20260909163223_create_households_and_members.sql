create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'My Household' check (btrim(name) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  status text not null default 'active' check (status in ('active', 'invited', 'left')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (household_id, user_id)
);

create index if not exists household_members_user_idx
  on public.household_members (user_id, status);

create index if not exists household_members_household_idx
  on public.household_members (household_id, status);

alter table public.household_profiles
  add column if not exists household_id uuid references public.households(id) on delete set null;

insert into public.households (owner_user_id, name)
select hp.user_id, 'My Household'
from public.household_profiles hp
where not exists (
  select 1 from public.households h where h.owner_user_id = hp.user_id
);

update public.household_profiles hp
set household_id = h.id
from public.households h
where h.owner_user_id = hp.user_id
  and hp.household_id is null;

insert into public.household_members (household_id, user_id, role, status)
select h.id, h.owner_user_id, 'owner', 'active'
from public.households h
where not exists (
  select 1 from public.household_members hm
  where hm.household_id = h.id and hm.user_id = h.owner_user_id
);

create or replace function public.is_active_household_member(target_household_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = (select auth.uid())
      and hm.status = 'active'
  );
$$;

revoke all on table public.households from anon;
revoke all on table public.household_members from anon;
revoke all on function public.is_active_household_member(uuid) from anon;

grant select, insert, update, delete on table public.households to authenticated;
grant select, insert on table public.household_members to authenticated;
grant execute on function public.is_active_household_member(uuid) to authenticated;
grant all on table public.households to service_role;
grant all on table public.household_members to service_role;
grant all on function public.is_active_household_member(uuid) to service_role;

alter table public.households enable row level security;
alter table public.household_members enable row level security;

drop policy if exists household_select_member on public.households;
drop policy if exists household_insert_owner on public.households;
drop policy if exists household_update_owner on public.households;
drop policy if exists household_delete_owner on public.households;
drop policy if exists household_member_select_self on public.household_members;
drop policy if exists household_member_insert_self on public.household_members;

create policy household_select_member
on public.households
for select
to authenticated
using (
  (select auth.uid()) = owner_user_id
  or public.is_active_household_member(id)
);

create policy household_insert_owner
on public.households
for insert
to authenticated
with check ((select auth.uid()) = owner_user_id);

create policy household_update_owner
on public.households
for update
to authenticated
using ((select auth.uid()) = owner_user_id)
with check ((select auth.uid()) = owner_user_id);

create policy household_delete_owner
on public.households
for delete
to authenticated
using ((select auth.uid()) = owner_user_id);

create policy household_member_select_self
on public.household_members
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy household_member_insert_self
on public.household_members
for insert
to authenticated
with check ((select auth.uid()) = user_id);
