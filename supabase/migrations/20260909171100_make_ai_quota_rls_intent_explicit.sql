drop policy if exists ai_daily_quota_no_client_access on public.ai_daily_quota;
drop policy if exists ai_quota_reservations_no_client_access on public.ai_quota_reservations;

create policy ai_daily_quota_no_client_access
on public.ai_daily_quota
for all
to authenticated
using (false)
with check (false);

create policy ai_quota_reservations_no_client_access
on public.ai_quota_reservations
for all
to authenticated
using (false)
with check (false);
