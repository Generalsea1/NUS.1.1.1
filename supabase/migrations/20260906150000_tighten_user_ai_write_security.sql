-- User-owned AI connection security.
-- Client applications may read their own connection state, but provider
-- credentials and AI-run creation remain server-controlled.

drop policy if exists users_manage_own_ai_connections on public.user_ai_connections;

drop policy if exists users_read_own_ai_connections on public.user_ai_connections;
create policy users_read_own_ai_connections
  on public.user_ai_connections
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists users_insert_own_ai_runs on public.user_ai_runs;
