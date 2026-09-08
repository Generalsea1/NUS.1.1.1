create table if not exists public.ai_daily_quota (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  successful_requests integer not null default 0 check (successful_requests >= 0),
  primary key (user_id, usage_date)
);

create table if not exists public.ai_quota_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_quota_reservations_lookup_idx
  on public.ai_quota_reservations(user_id, usage_date, expires_at);

alter table public.ai_daily_quota enable row level security;
alter table public.ai_quota_reservations enable row level security;

revoke all on table public.ai_daily_quota from anon, authenticated;
revoke all on table public.ai_quota_reservations from anon, authenticated;

drop function if exists public.reserve_ai_quota(uuid, date, integer, integer);
drop function if exists public.finalize_ai_quota(uuid, uuid, date);
drop function if exists public.release_ai_quota(uuid, uuid, date);

create or replace function public.reserve_ai_quota(
  p_user_id uuid,
  p_usage_date date,
  p_limit integer default 10,
  p_ttl_seconds integer default 300
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_reservation_id uuid := gen_random_uuid();
  v_successful integer;
  v_reserved integer;
begin
  if p_limit < 1 or p_ttl_seconds < 1 then
    raise exception 'invalid quota parameters';
  end if;

  insert into public.ai_daily_quota(user_id, usage_date, successful_requests)
  values (p_user_id, p_usage_date, 0)
  on conflict (user_id, usage_date) do nothing;

  select successful_requests
    into v_successful
    from public.ai_daily_quota
   where user_id = p_user_id
     and usage_date = p_usage_date
   for update;

  delete from public.ai_quota_reservations
   where user_id = p_user_id
     and usage_date = p_usage_date
     and expires_at <= now();

  select count(*)::integer
    into v_reserved
    from public.ai_quota_reservations
   where user_id = p_user_id
     and usage_date = p_usage_date
     and expires_at > now();

  if v_successful + v_reserved >= p_limit then
    return null;
  end if;

  insert into public.ai_quota_reservations(id, user_id, usage_date, expires_at)
  values (v_reservation_id, p_user_id, p_usage_date, now() + make_interval(secs => p_ttl_seconds));

  return v_reservation_id;
end;
$$;

create or replace function public.finalize_ai_quota(
  p_user_id uuid,
  p_reservation_id uuid,
  p_usage_date date
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_deleted integer;
begin
  delete from public.ai_quota_reservations
   where id = p_reservation_id
     and user_id = p_user_id
     and usage_date = p_usage_date;
  get diagnostics v_deleted = row_count;

  if v_deleted <> 1 then
    return false;
  end if;

  update public.ai_daily_quota
     set successful_requests = successful_requests + 1
   where user_id = p_user_id
     and usage_date = p_usage_date;

  return true;
end;
$$;

create or replace function public.release_ai_quota(
  p_user_id uuid,
  p_reservation_id uuid,
  p_usage_date date
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_deleted integer;
begin
  delete from public.ai_quota_reservations
   where id = p_reservation_id
     and user_id = p_user_id
     and usage_date = p_usage_date;
  get diagnostics v_deleted = row_count;
  return v_deleted = 1;
end;
$$;

revoke all on function public.reserve_ai_quota(uuid, date, integer, integer) from public, anon, authenticated;
revoke all on function public.finalize_ai_quota(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.release_ai_quota(uuid, uuid, date) from public, anon, authenticated;

grant execute on function public.reserve_ai_quota(uuid, date, integer, integer) to service_role;
grant execute on function public.finalize_ai_quota(uuid, uuid, date) to service_role;
grant execute on function public.release_ai_quota(uuid, uuid, date) to service_role;
