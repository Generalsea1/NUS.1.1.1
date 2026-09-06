# Google Sign-In setup for NUS

1. In Supabase Auth, enable the Google provider and configure the Google OAuth client IDs/secrets.
2. Add `nus://auth-callback` to the allowed redirect URLs in Supabase.
3. Configure the Android app intent filter for the same `nus` URI scheme.
4. Google Sign-In through Supabase is for NUS identity. Gemini authorization is a separate OAuth consent flow and must be granted separately by the user.
