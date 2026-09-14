# NUS 2.0

NUS is a bilingual (Arabic / English) **Personal + Household Life Operating System** with the **NUS Financial Brain / Household CFO** as its strategic core.

## Current product state

The authenticated product currently includes:

- Supabase authentication and household identity.
- Onboarding with household and financial baseline data.
- NUS Today with unified work across reminders, appointments, household tasks, and enabled obligations.
- Quick Add for reminders, appointments, shopping, and confirmed expense capture, with Arabic/Egyptian voice input where available.
- Finance foundations for income, expenses, recurring expenses, obligations, installments, budget planning, debt payoff planning, affordability analysis, cash-flow forecasting, and deterministic anomaly/budget-pressure insights.
- A financial command center that presents actual income, obligations, actual spending, expected recurring spending, spending distribution, and budget pressure from authoritative data.
- A proactive NUS opening insight when reliable financial context is available.
- **Ask NUS** as the single user-facing AI conversation surface for financial questions. The response is structured as summary, facts, priorities, and warnings where needed; the provider implementation remains behind the authenticated server boundary.
- Household members, roles, invitations, shared tasks, and shared shopping.
- Deterministic proactive appointment notifications and notification controls.

The former user-facing Copilot page/provider was retired from the application surface. Legacy server compatibility may remain deployed until the production deployment lifecycle explicitly removes it.

## Product promise

> **"قل لي ماذا يحدث الآن، وماذا يجب أن أفعل بعد ذلك بحياتي ومالي وأسرتي."**

The product is not a generic chatbot or an expense tracker with a chat screen attached. Its purpose is to turn household facts into understandable financial decisions without inventing balances, currencies, or outcomes.

## Engineering standards

- Real functionality before visual polish.
- User-entered facts remain authoritative.
- No fake production behavior.
- AI is an intelligence layer, not the source of truth.
- Provider credentials remain server-side.
- Financial writes require explicit user intent/confirmation where applicable.
- Independent financial reads are started concurrently where safe to reduce avoidable startup latency.
- Every meaningful feature must be implemented, integrated, tested, analyzed, CI-verified, and APK-verified when Android-facing.

## Repository

`Generalsea1/NUS.1.1.1`

## Version

`2.0.0+2`

## Android build

GitHub Actions runs Flutter analysis and the full test suite, builds a release APK, verifies the processed APK manifest/icon resources, and uploads the release artifact.

## Release hardening status

Release hardening is not declared complete until the external Supabase Auth leaked-password protection setting is enabled and the Financial Advisor has been live-tested end-to-end with an authenticated user against the production Gemini path. A passing repository test suite does not substitute for that runtime evidence.
