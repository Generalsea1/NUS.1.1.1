drop policy if exists household_member_insert_self on public.household_members;

create policy household_member_insert_admin
on public.household_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.household_members actor
    where actor.household_id = household_members.household_id
      and actor.user_id = (select auth.uid())
      and actor.status = 'active'
      and actor.role in ('owner', 'admin')
  )
  and household_members.role = 'member'
  and household_members.status = 'active'
);

create table if not exists public.household_shopping_lists (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_shopping_items (
  id uuid primary key default gen_random_uuid(),
  shopping_list_id uuid not null references public.household_shopping_lists(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  quantity text,
  is_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists household_shopping_lists_household_idx
  on public.household_shopping_lists (household_id, updated_at desc);
create index if not exists household_shopping_items_list_idx
  on public.household_shopping_items (shopping_list_id, created_at asc);

create or replace function public.is_active_shopping_list_member(target_list_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.household_shopping_lists sl
    where sl.id = target_list_id
      and public.is_active_household_member(sl.household_id)
  );
$$;

revoke all on table public.household_shopping_lists from anon;
revoke all on table public.household_shopping_items from anon;
revoke all on function public.is_active_shopping_list_member(uuid) from anon;

grant select, insert, update, delete on table public.household_shopping_lists to authenticated;
grant select, insert, update, delete on table public.household_shopping_items to authenticated;
grant execute on function public.is_active_shopping_list_member(uuid) to authenticated;

grant all on table public.household_shopping_lists to service_role;
grant all on table public.household_shopping_items to service_role;
grant all on function public.is_active_shopping_list_member(uuid) to service_role;

alter table public.household_shopping_lists enable row level security;
alter table public.household_shopping_items enable row level security;

drop policy if exists household_shopping_list_select_member on public.household_shopping_lists;
drop policy if exists household_shopping_list_insert_member on public.household_shopping_lists;
drop policy if exists household_shopping_list_update_member on public.household_shopping_lists;
drop policy if exists household_shopping_list_delete_member on public.household_shopping_lists;

drop policy if exists household_shopping_item_select_member on public.household_shopping_items;
drop policy if exists household_shopping_item_insert_member on public.household_shopping_items;
drop policy if exists household_shopping_item_update_member on public.household_shopping_items;
drop policy if exists household_shopping_item_delete_member on public.household_shopping_items;

create policy household_shopping_list_select_member
on public.household_shopping_lists
for select
to authenticated
using (public.is_active_household_member(household_id));

create policy household_shopping_list_insert_member
on public.household_shopping_lists
for insert
to authenticated
with check (
  public.is_active_household_member(household_id)
  and created_by = (select auth.uid())
);

create policy household_shopping_list_update_member
on public.household_shopping_lists
for update
to authenticated
using (public.is_active_household_member(household_id))
with check (public.is_active_household_member(household_id));

create policy household_shopping_list_delete_member
on public.household_shopping_lists
for delete
to authenticated
using (public.is_active_household_member(household_id));

create policy household_shopping_item_select_member
on public.household_shopping_items
for select
to authenticated
using (public.is_active_shopping_list_member(shopping_list_id));

create policy household_shopping_item_insert_member
on public.household_shopping_items
for insert
to authenticated
with check (public.is_active_shopping_list_member(shopping_list_id));

create policy household_shopping_item_update_member
on public.household_shopping_items
for update
to authenticated
using (public.is_active_shopping_list_member(shopping_list_id))
with check (public.is_active_shopping_list_member(shopping_list_id));

create policy household_shopping_item_delete_member
on public.household_shopping_items
for delete
to authenticated
using (public.is_active_shopping_list_member(shopping_list_id));
