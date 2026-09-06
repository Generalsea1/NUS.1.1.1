# ai-provider-connect

This Edge Function starts and completes the user-owned Gemini OAuth flow.

Required Supabase secrets:

- `GEMINI_GOOGLE_CLIENT_ID`
- `GEMINI_GOOGLE_CLIENT_SECRET`
- `GEMINI_OAUTH_CALLBACK_URL` — the deployed Edge Function `/callback` URL registered in Google Cloud.
- `AI_TOKEN_ENCRYPTION_KEY` — a strong random server-side secret used to encrypt user OAuth tokens.

The callback validates the short-lived OAuth state, exchanges the authorization code server-side, encrypts access/refresh tokens, and stores them in `user_ai_connections`. Provider tokens are never returned to the mobile app.
