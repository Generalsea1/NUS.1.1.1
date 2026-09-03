# NUS — Auth Domain + Session Architecture

This phase establishes only the application authentication/session boundary. It does not add login UI, provider flows, profiles, database schema, RLS, or social authentication.

## Architecture

```text
NUS application
    |
    v
AuthRepository
    |
    +--> AuthState / AuthSession / AuthUser
    |
    v
SupabaseAuthRepository
    |
    v
SupabaseService
    |
    v
Supabase client
```

The domain types contain no Supabase imports or provider-specific session/event objects. The Supabase adapter alone translates provider state into the application contract.

## Missing configuration

When `SUPABASE_URL` or `SUPABASE_PUBLISHABLE_KEY` is absent or invalid, the Supabase client remains uninitialized and the auth repository reports `UnauthenticatedAuthState`. No fake user is created and local-first reminder functionality remains independent.

## Session persistence

NUS does not manually store access tokens or refresh tokens. Supabase remains responsible for its authentication session persistence; the application consumes only mapped identity information.

## Lifecycle

`SupabaseAuthRepository` creates at most one auth-state subscription. `dispose()` cancels it and closes the application auth stream. Callbacks ignore events after disposal.

## Future providers

Future Email and Native Google authentication implementations must enter through `AuthRepository`. UI and business logic must not call Supabase Auth directly. No provider login is implemented in this phase.

## Reminder isolation

`ScheduleStore` continues to own local reminder persistence via `SharedPreferences` using `nos.schedule.v1`. `NotificationService` remains the local notification scheduler.
