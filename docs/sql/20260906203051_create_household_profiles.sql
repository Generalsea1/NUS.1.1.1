-- NUS household profile persistence
-- Applied to Supabase production project girxiyfineqruhwbnfbe.

create table if not exists public.household_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  country_code text not null default 'EG',
  region text,
  currency_code text not null default 'EGP',
  household_size integer not null default 1 check (household_size > 0 and household_size <= 50),
  adults integer not null default 1 check (adults > 0 and adults <= 20),
  children integer not null default 0 check (children >= 0 and children <= 30),
  housing_type text not null default 'rent' check (housing_type in ('rent','owned','family','other')),
  income_frequency text not null default 'monthly' check (income_frequency in ('monthly','weekly','biweekly','irregular')),
  monthly_income integer not null default 0 check (monthly_income >= 0),
  recurring_debt integer not null default 0 check (recurring_debt >= 0),
  emergency_target integer not null default 0 check (emergency_target >= 0),
  budget_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.household_profiles enable row level security;

create policy "household_profiles_select_own"
on public.household_profiles for select to authenticated
using (auth.uid() = user_id);

create policy "household_profiles_insert_own"
on public.household_profiles for insert to authenticated
with check (auth.uid() = user_id);

create policy "household_profiles_update_own"
on public.household_profiles for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

alter table public.household_profiles
  add column if not exists budget_snapshot jsonb not null default '{}'::jsonb;
