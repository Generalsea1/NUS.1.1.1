# NUS — Supabase foundation

NUS now includes a foundational Supabase client boundary. Authentication, profiles, database tables, sync, Storage, Realtime, and Google Sign-In are not implemented by this phase.

## Configuration

The Flutter application reads these values at build/runtime configuration time using Dart defines:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Example local/debug build configuration:

```text
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Do not put these values in source files, and do not commit `.env` files containing credentials.

The publishable/legacy anon client key is intended for the client application. A `service_role` key, database password, OAuth client secret, or any other server secret must never be shipped in the Flutter application or committed to Git.

## Missing configuration

When the two Dart defines are absent or malformed, NUS does not initialize the Supabase client and continues in local-first mode. Existing reminder persistence remains on `SharedPreferences` under `nos.schedule.v1`; local notifications continue to operate without a live Supabase backend.

When configuration is supplied, the single `SupabaseService` boundary initializes `Supabase.instance.client`. Live project connectivity is not part of the repository's default CI build and must be verified in a later environment-specific phase with real project configuration.

## Development / CI / Production

- Development: provide the two Dart defines locally when Supabase access is needed.
- CI: inject the same values through the CI/build environment only when a later CI job needs live Supabase connectivity; do not commit them to the workflow file.
- Production: provide the values through the release/build system; keep all server-side secrets outside the application.

No authentication or database schema is created by this foundation.
