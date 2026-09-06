# AI provider connection configuration

Required Supabase Function Secrets:

- `GEMINI_GOOGLE_CLIENT_ID`
- `GEMINI_GOOGLE_CLIENT_SECRET`
- `GEMINI_OAUTH_CALLBACK_URL` (the deployed `ai-provider-connect` callback URL)
- `AI_TOKEN_ENCRYPTION_KEY` (random high-entropy secret used only by the Edge Function)
- `GEMINI_GOOGLE_CLOUD_PROJECT_ID`
- `GEMINI_MODEL` (optional; defaults to `gemini-3.7-flash`)

Google OAuth must allow the callback URL and request the `cloud-platform` scope. The NUS Android deep link used for application authentication is `nus://auth-callback`.
