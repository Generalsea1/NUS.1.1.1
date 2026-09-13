-- Preserve existing authorization semantics while avoiding repeated auth.uid()
-- evaluation for every row in these user-scoped financial policies.

alter policy income_sources_select_own on public.income_sources
  using ((select auth.uid()) = user_id);
alter policy income_sources_insert_own on public.income_sources
  with check ((select auth.uid()) = user_id);
alter policy income_sources_update_own on public.income_sources
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy income_sources_delete_own on public.income_sources
  using ((select auth.uid()) = user_id);

alter policy obligations_select_own on public.obligations
  using ((select auth.uid()) = user_id);
alter policy obligations_insert_own on public.obligations
  with check ((select auth.uid()) = user_id);
alter policy obligations_update_own on public.obligations
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy obligations_delete_own on public.obligations
  using ((select auth.uid()) = user_id);

alter policy recurring_expense_select_own on public.recurring_expense_definitions
  using ((select auth.uid()) = user_id);
alter policy recurring_expense_insert_own on public.recurring_expense_definitions
  with check ((select auth.uid()) = user_id);
alter policy recurring_expense_update_own on public.recurring_expense_definitions
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy recurring_expense_delete_own on public.recurring_expense_definitions
  using ((select auth.uid()) = user_id);

alter policy expense_records_select_own on public.expense_records
  using ((select auth.uid()) = user_id);
alter policy expense_records_insert_own on public.expense_records
  with check ((select auth.uid()) = user_id);
alter policy expense_records_update_own on public.expense_records
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy expense_records_delete_own on public.expense_records
  using ((select auth.uid()) = user_id);
