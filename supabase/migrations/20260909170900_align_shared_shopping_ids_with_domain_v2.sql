drop policy if exists household_shopping_item_select_member on public.household_shopping_items;
drop policy if exists household_shopping_item_insert_member on public.household_shopping_items;
drop policy if exists household_shopping_item_update_member on public.household_shopping_items;
drop policy if exists household_shopping_item_delete_member on public.household_shopping_items;
drop function if exists public.is_active_shopping_list_member(uuid);

alter table public.household_shopping_items drop constraint if exists household_shopping_items_shopping_list_id_fkey;
alter table public.household_shopping_lists alter column id drop default;
alter table public.household_shopping_items alter column id drop default;
alter table public.household_shopping_lists alter column id type text using id::text;
alter table public.household_shopping_items alter column id type text using id::text;
alter table public.household_shopping_items alter column shopping_list_id type text using shopping_list_id::text;
alter table public.household_shopping_lists alter column id set default (gen_random_uuid()::text);
alter table public.household_shopping_items alter column id set default (gen_random_uuid()::text);

alter table public.household_shopping_items
  add constraint household_shopping_items_shopping_list_id_fkey
  foreign key (shopping_list_id) references public.household_shopping_lists(id) on delete cascade;

create or replace function public.is_active_shopping_list_member(target_list_id text)
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

revoke all on function public.is_active_shopping_list_member(text) from anon;
grant execute on function public.is_active_shopping_list_member(text) to authenticated;
grant all on function public.is_active_shopping_list_member(text) to service_role;

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
