# NUS — Profile Data Architecture

## Scope

Phase 4 establishes only the foundational profile data architecture. It does not implement Email authentication, Google Sign-In, OAuth, login/register UI, social features, avatar upload, Storage, Realtime, or reminder synchronization.

## Canonical identity

The authenticated identity is the canonical key:

```text
Supabase Auth
    |
    └── auth.users.id
            |
            ▼
    public.profiles.id
```

`public.profiles.id` is therefore the profile primary key and a foreign key to `auth.users.id` with `ON DELETE CASCADE`. No independent profile id and no separate `auth_user_id` column are introduced.

The application obtains the current identity only through the Phase 3 `AuthRepository` boundary. UI code does not access Supabase Auth directly.

## Minimum profile model

The Phase 4 model contains only fields justified by the current architecture:

- `id` — stable authenticated identity key.
- `display_name` — application-facing profile name.
- `avatar_url` — future remote avatar reference; no upload mechanism is implemented here.
- `created_at` — profile creation timestamp.
- `updated_at` — profile modification timestamp.

`email` is intentionally not duplicated into `profiles`. Supabase Auth already owns the authenticated email identity, and duplicating it in the profile table would create a second source of truth. The application can obtain email from `AuthUser` when needed.

`username`, `bio`, and `cover_url` are intentionally omitted because Phase 4 has no current requirement for them.

## Application boundary

`Profile` is the NUS application model. `ProfileRepository` is the application repository contract. Supabase-specific row mapping remains inside `SupabaseProfileRepository` / `SupabaseProfileMapper`.

The repository currently exposes only the operation required to establish authenticated profile loading:

```text
getCurrentProfile()
```

Future create/update operations can be added when a product requirement exists. `getProfileById()` is intentionally not exposed yet, avoiding arbitrary identity selection before the product explicitly requires cross-user profile access.

## Unauthenticated behavior

When `AuthRepository.currentState` is unauthenticated, `getCurrentProfile()` returns `null` and performs no database fetch. There is no anonymous profile creation, no fake user, and no crash path.

When Supabase is not configured, the repository also returns `null` because `SupabaseService.client` is unavailable. This keeps profile infrastructure optional and preserves the local-first reminder path.

## Intended database schema

No `supabase/migrations` directory or established Supabase migration process exists in the accepted Phase 3 repository. Therefore Phase 4 does not invent or add a migration/deployment framework. The following SQL is the canonical schema specification to apply when the project adopts its existing/approved Supabase database deployment mechanism:

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_profiles_updated_at();
```

### Important security status

RLS is intentionally deferred to the later security phase. The schema above is **not production-secure by itself** until table grants and RLS policies are configured. Do not treat the Phase 4 repository boundary or schema specification as proof that production database access is secured.

The intended ownership rule for the later RLS phase is: the authenticated user's `auth.uid()` may access only the row whose `id` equals that authenticated identity. Clients must never be trusted to choose another user's profile id for a current-profile operation.

No `service_role`, database password, OAuth client secret, or other server secret is used or required by this architecture. The Flutter application must continue to use only the existing `SupabaseService` and its publishable client configuration.

## Local-first isolation

This phase does not modify `ScheduleStore`, `SharedPreferences`, `nos.schedule.v1`, `NotificationService`, or the accepted reminder lifecycle behavior. Profile availability is not a prerequisite for creating, storing, scheduling, or canceling local reminders.
