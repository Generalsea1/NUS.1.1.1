-- Add covering indexes for foreign keys reported by Supabase Performance Advisor.
-- These indexes support parent-row update/delete checks and household-scoped
-- relation lookups; existing application behavior and RLS predicates are unchanged.

create index if not exists expense_records_obligation_fk_idx
  on public.expense_records (obligation_id);

create index if not exists expense_records_recurring_definition_fk_idx
  on public.expense_records (recurring_definition_id);

create index if not exists household_invitations_accepted_by_fk_idx
  on public.household_invitations (accepted_by);

create index if not exists household_invitations_created_by_fk_idx
  on public.household_invitations (created_by);

create index if not exists household_invitations_revoked_by_fk_idx
  on public.household_invitations (revoked_by);

create index if not exists household_profiles_household_id_fk_idx
  on public.household_profiles (household_id);

create index if not exists household_shopping_lists_created_by_fk_idx
  on public.household_shopping_lists (created_by);

create index if not exists households_owner_user_id_fk_idx
  on public.households (owner_user_id);
