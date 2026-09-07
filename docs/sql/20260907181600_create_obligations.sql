-- NUS Slice 3 — Obligation Engine persistence.
-- Preserve household_profiles.recurring_debt and budget_snapshot for compatibility.

create table if not exists public.obligations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  type text not null check (type in ('rent','loan','school','utilities','insurance','subscription','family_support','transportation','other','legacy')),
  amount bigint not null check (amount > 0),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  frequency text not null check (frequency in ('monthly','weekly','biweekly','quarterly','yearly')),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists obligations_user_enabled_idx on public.obligations(user_id, enabled);
create unique index if not exists obligations_one_legacy_per_user_idx on public.obligations(user_id) where type = 'legacy';

alter table public.obligations enable row level security;
grant select, insert, update, delete on public.obligations to authenticated;

create policy "obligations_select_own" on public.obligations for select to authenticated using (auth.uid() = user_id);
create policy "obligations_insert_own" on public.obligations for insert to authenticated with check (auth.uid() = user_id);
create policy "obligations_update_own" on public.obligations for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "obligations_delete_own" on public.obligations for delete to authenticated using (auth.uid() = user_id);

create or replace function public.touch_obligation_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists obligations_touch_updated_at on public.obligations;
create trigger obligations_touch_updated_at before update on public.obligations for each row execute function public.touch_obligation_updated_at();

insert into public.obligations (user_id,name,type,amount,currency_code,frequency,enabled)
select hp.user_id,'الالتزامات الأولية من إعداد البيت','legacy',legacy_amount,upper(hp.currency_code),'monthly',true
from (
  select user_id,currency_code,recurring_debt,budget_snapshot,
    case
      when recurring_debt > 0 then recurring_debt
      when (budget_snapshot->>'initialRecurringObligations') ~ '^[0-9]+$' then (budget_snapshot->>'initialRecurringObligations')::bigint
      else 0
    end as legacy_amount
  from public.household_profiles
) hp
where hp.legacy_amount > 0
on conflict do nothing;

create or replace function public.seed_legacy_obligation()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.recurring_debt > 0 then
    insert into public.obligations (user_id,name,type,amount,currency_code,frequency,enabled)
    values (new.user_id,'الالتزامات الأولية من إعداد البيت','legacy',new.recurring_debt,upper(new.currency_code),'monthly',true)
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists household_profiles_seed_legacy_obligation on public.household_profiles;
create trigger household_profiles_seed_legacy_obligation after insert on public.household_profiles for each row execute function public.seed_legacy_obligation();
