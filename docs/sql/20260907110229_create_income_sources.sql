-- NUS Slice 2 income engine persistence.
-- Applied to Supabase production project girxiyfineqruhwbnfbe.
-- Legacy monthly_income is migrated into one explicit legacy source so existing
-- household profiles keep their real stored income without inventing a value.

create table if not exists public.income_sources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  source_type text not null check (source_type in ('salary','pension','rent','interest','freelance','business','other','legacy')),
  amount bigint not null check (amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  frequency text not null check (frequency in ('monthly','weekly','biweekly','quarterly','yearly')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists income_sources_user_enabled_idx
  on public.income_sources(user_id, enabled);

create unique index if not exists income_sources_one_legacy_per_user_idx
  on public.income_sources(user_id)
  where source_type = 'legacy';

alter table public.income_sources enable row level security;

create policy "income_sources_select_own"
on public.income_sources for select to authenticated
using (auth.uid() = user_id);

create policy "income_sources_insert_own"
on public.income_sources for insert to authenticated
with check (auth.uid() = user_id);

create policy "income_sources_update_own"
on public.income_sources for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "income_sources_delete_own"
on public.income_sources for delete to authenticated
using (auth.uid() = user_id);

create or replace function public.touch_income_source_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists income_sources_touch_updated_at on public.income_sources;
create trigger income_sources_touch_updated_at
before update on public.income_sources
for each row execute function public.touch_income_source_updated_at();

insert into public.income_sources (user_id, name, source_type, amount, currency_code, frequency, enabled)
select
  hp.user_id,
  'الدخل الأساسي من إعداد البيت',
  'legacy',
  hp.monthly_income,
  upper(hp.currency_code),
  'monthly',
  true
from public.household_profiles hp
where hp.monthly_income > 0
on conflict do nothing;

create or replace function public.seed_legacy_income_source()
returns trigger
language plpgsql
as $$
begin
  if new.monthly_income > 0 then
    insert into public.income_sources (user_id, name, source_type, amount, currency_code, frequency, enabled)
    values (
      new.user_id,
      'الدخل الأساسي من إعداد البيت',
      'legacy',
      new.monthly_income,
      upper(new.currency_code),
      'monthly',
      true
    )
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists household_profiles_seed_legacy_income on public.household_profiles;
create trigger household_profiles_seed_legacy_income
after insert on public.household_profiles
for each row execute function public.seed_legacy_income_source();
