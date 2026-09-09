create table if not exists public.installment_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (btrim(title) <> ''),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  total_minor_units bigint not null check (total_minor_units > 0),
  down_payment_minor_units bigint not null check (down_payment_minor_units >= 0),
  number_of_installments integer not null check (number_of_installments > 0 and number_of_installments <= 120),
  paid_installments integer not null default 0 check (paid_installments >= 0 and paid_installments <= number_of_installments),
  first_due_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint installment_plans_down_less_than_total check (down_payment_minor_units < total_minor_units)
);

create index if not exists installment_plans_user_due_idx on public.installment_plans(user_id, first_due_date asc, created_at desc);

revoke all on table public.installment_plans from anon;
grant select, insert, update, delete on public.installment_plans to authenticated;
grant all on public.installment_plans to service_role;
alter table public.installment_plans enable row level security;

drop policy if exists installment_plans_select_own on public.installment_plans;
drop policy if exists installment_plans_insert_own on public.installment_plans;
drop policy if exists installment_plans_update_own on public.installment_plans;
drop policy if exists installment_plans_delete_own on public.installment_plans;

create policy installment_plans_select_own on public.installment_plans for select to authenticated using (user_id = (select auth.uid()));
create policy installment_plans_insert_own on public.installment_plans for insert to authenticated with check (user_id = (select auth.uid()));
create policy installment_plans_update_own on public.installment_plans for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy installment_plans_delete_own on public.installment_plans for delete to authenticated using (user_id = (select auth.uid()));

create or replace function public.touch_installment_plan_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists installment_plans_touch_updated_at on public.installment_plans;
create trigger installment_plans_touch_updated_at before update on public.installment_plans for each row execute function public.touch_installment_plan_updated_at();
