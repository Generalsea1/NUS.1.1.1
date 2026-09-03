# NOS v1.0.0

A bilingual (Arabic / English) personal life organizer, designed to grow from a lightweight free MVP into a global product.

## Product roadmap
1. Smart Schedule — current foundation: clean home screen, bilingual RTL/LTR experience, quick reminder entry.
2. Expenses — fast monthly expense capture, categories and summaries.
3. Shopping — lists connected to everyday spending.
4. Recipes — quantities, grams, timings, servings and shopping-list generation.
5. Invoices & debts — personal bills, customer/people balances and due-date reminders.
6. AI layer — optional assistant for natural-language and voice commands; core features must remain useful without AI.

## Engineering principles
- Start local-first and keep the first MVP inexpensive.
- Do not require users to own a ChatGPT/Gemini account.
- Keep AI behind a server-side abstraction so providers can change later.
- Supabase is reserved for authenticated sync, backup and future multi-device features; secrets are never committed to Git.
- Arabic and English are first-class from day one, including RTL/LTR layout.

## Repository
`Generalsea1/NUS.1.1.1`

## Version
`1.0.0+1`

## Build
The repository includes a GitHub Actions workflow that generates the Android project, runs analysis, builds a debug APK and uploads it as an artifact.
