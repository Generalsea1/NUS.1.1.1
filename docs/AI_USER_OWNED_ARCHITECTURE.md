# NUS User-Owned AI Architecture

NUS treats application authentication and AI authorization as two separate contracts.

## Identity

A user signs into NUS with Google through Supabase Auth. The resulting Supabase user id is the owner key for household data and AI history.

## AI authorization

Gemini is connected separately through Google OAuth. The OAuth access and refresh tokens are encrypted server-side and stored only in `user_ai_connections`. The mobile client never stores provider secrets.

OpenAI/ChatGPT remains a separate provider option. `Sign in with ChatGPT` is identity only and does not grant access to ChatGPT conversations, memory, or ChatGPT billing/API usage.

## Execution

`HouseholdBudgetAiProvider` invokes the authenticated `household-budget-ai` Edge Function. The function resolves the latest connected provider for the authenticated NUS user, calls the provider with that user's authorization, validates the returned budget against available income, and writes the structured result to `user_ai_runs`.

## Security

- `user_ai_connections` and `user_ai_runs` are scoped by `auth.uid()` through RLS.
- Provider tokens are never returned to Flutter.
- Provider credentials are stored encrypted at rest.
- User-entered household amounts remain authoritative.
- AI-generated amounts are limited to missing planning envelopes.
- Server-side validation prevents AI output from exceeding the available household budget.
