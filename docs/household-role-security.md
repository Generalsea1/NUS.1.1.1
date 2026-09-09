# Household role security boundary

Household roles are `owner`, `admin`, and `member`.

The owner cannot be changed through the member-role UI. Only an active owner or admin may change a non-owner member between `member` and `admin`. The client performs validation, but authorization is enforced by Supabase RLS through the `can_manage_household` security-definer helper.

Role changes are not performed through service-role credentials and do not expose user email/profile data to the roster UI.
