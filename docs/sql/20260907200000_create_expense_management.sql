-- NUS Slice 4 — authoritative household expense management.
-- Exactly one migration owns actual occurrences and recurring definitions.

create table if not exists public.recurring_expense_definitions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  amount_minor_units bigint not null check (amount_minor_units > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  category_code text not null check (category_code in ('food','housing','utilities','transportation','education','healthcare','insurance','family','subscriptions','shopping','entertainment','debt','maintenance','other')),
  frequency text not null check (frequency in ('monthly','weekly','biweekly','quarterly','yearly')),
  enabled boolean not null default true,
  start_date date not null,
  end_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recurring_expense_dates_valid check (end_date is null or end_date >= start_date)
);

create table if not exists public.expense_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount_minor_units bigint not null check (amount_minor_units > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  occurred_on date not null,
  category_code text not null check (category_code in ('food','housing','utilities','transportation','education','healthcare','insurance','family','subscriptions','shopping','entertainment','debt','maintenance','other')),
  expense_type text not null check (expense_type in ('one_time','variable','recurring')),
  merchant text,
  description text,
  payment_method text,
  recurring_definition_id uuid references public.recurring_expense_definitions(id) on delete set null,
  obligation_id uuid references public.obligations(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expense_recurring_link_valid check (expense_type = 'recurring' or recurring_definition_id is null)
);

create index if not exists expense_records_user_occurred_idx on public.expense_records(user_id, occurred_on);
create index if not exists expense_records_user_category_date_idx on public.expense_records(user_id, category_code, occurred_on);
create index if not exists expense_records_user_recurring_idx on public.expense_records(user_id, recurring_definition_id);
create index if not exists expense_records_user_obligation_idx on public.expense_records(user_id, obligation_id);
create index if not exists recurring_expense_user_enabled_idx on public.recurring_expense_definitions(user_id, enabled);
create index if not exists recurring_expense_user_start_idx on public.recurring_expense_definitions(user_id, start_date);

alter table public.recurring_expense_definitions enable row level security;
alter table public.expense_records enable row level security;

grant select, insert, update, delete on public.recurring_expense_definitions to authenticated;
grant select, insert, update, delete on public.expense_records to authenticated;

drop policy if exists "recurring_expense_select_own" on public.recurring_expense_definitions;
create policy "recurring_expense_select_own" on public.recurring_expense_definitions for select to authenticated using (auth.uid() = user_id);
drop policy if exists "recurring_expense_insert_own" on public.recurring_expense_definitions;
create policy "recurring_expense_insert_own" on public.recurring_expense_definitions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "recurring_expense_update_own" on public.recurring_expense_definitions;
create policy "recurring_expense_update_own" on public.recurring_expense_definitions for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "recurring_expense_delete_own" on public.recurring_expense_definitions;
create policy "recurring_expense_delete_own" on public.recurring_expense_definitions for delete to authenticated using (auth.uid() = user_id);

drop policy if exists "expense_records_select_own" on public.expense_records;
create policy "expense_records_select_own" on public.expense_records for select to authenticated using (auth.uid() = user_id);
drop policy if exists "expense_records_insert_own" on public.expense_records;
create policy "expense_records_insert_own" on public.expense_records for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "expense_records_update_own" on public.expense_records;
create policy "expense_records_update_own" on public.expense_records for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "expense_records_delete_own" on public.expense_records;
create policy "expense_records_delete_own" on public.expense_records for delete to authenticated using (auth.uid() = user_id);

create or replace function public.touch_recurring_expense_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists recurring_expense_touch_updated_at on public.recurring_expense_definitions;
create trigger recurring_expense_touch_updated_at before update on public.recurring_expense_definitions for each row execute function public.touch_recurring_expense_updated_at();

create or replace function public.touch_expense_record_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists expense_record_touch_updated_at on public.expense_records;
create trigger expense_record_touch_updated_at before update on public.expense_records for each row execute function public.touch_expense_record_updated_at();
