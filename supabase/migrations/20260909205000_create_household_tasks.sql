create table if not exists public.household_tasks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  title text not null check (btrim(title) <> '' and char_length(title) <= 300),
  due_at timestamptz,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((completed = false and completed_at is null) or completed = true)
);

create index if not exists household_tasks_household_due_idx
  on public.household_tasks(household_id, completed, due_at);
create index if not exists household_tasks_creator_idx
  on public.household_tasks(created_by, created_at);

alter table public.household_tasks enable row level security;
revoke all on table public.household_tasks from anon;
grant select, insert, update, delete on table public.household_tasks to authenticated;

drop policy if exists household_tasks_select_member on public.household_tasks;
drop policy if exists household_tasks_insert_member on public.household_tasks;
drop policy if exists household_tasks_update_member on public.household_tasks;
drop policy if exists household_tasks_delete_member on public.household_tasks;

create policy household_tasks_select_member
on public.household_tasks
for select to authenticated
using (public.is_active_household_member(household_id));

create policy household_tasks_insert_member
on public.household_tasks
for insert to authenticated
with check (
  public.is_active_household_member(household_id)
  and created_by = (select auth.uid())
);

create policy household_tasks_update_member
on public.household_tasks
for update to authenticated
using (public.is_active_household_member(household_id))
with check (public.is_active_household_member(household_id));

create policy household_tasks_delete_member
on public.household_tasks
for delete to authenticated
using (public.is_active_household_member(household_id));

create or replace function public.touch_household_task_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  if new.completed and old.completed = false then
    new.completed_at = coalesce(new.completed_at, now());
  elsif not new.completed then
    new.completed_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists household_tasks_touch_updated_at on public.household_tasks;
create trigger household_tasks_touch_updated_at
before update on public.household_tasks
for each row execute function public.touch_household_task_updated_at();
