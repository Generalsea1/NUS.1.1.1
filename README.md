# NUS 2.0

NUS is a bilingual (Arabic / English) **Personal + Household Life Operating System** focused on connecting daily life, household coordination, and financial decision support.

## Current product state

The authenticated product currently includes:

- Supabase authentication and household identity.
- Onboarding with household and financial baseline data.
- NUS Today with unified work across reminders, appointments, household tasks, and enabled obligations.
- Quick Add for reminders, appointments, shopping, and confirmed expense capture, with Arabic/Egyptian voice input where available.
- Finance foundations for income, expenses, recurring expenses, obligations, installments, budget planning, debt payoff planning, affordability analysis, and anomaly/budget-pressure insights where implemented.
- Household members, roles, invitations, shared tasks, and shared shopping.
- Financial Advisor and NUS Copilot entry points behind authenticated server-side AI boundaries.
- Deterministic proactive appointment notifications and notification controls.

## Product direction

NUS is being built around one core promise:

> **"قل لي ماذا يحدث الآن، وماذا يجب أن أفعل بعد ذلك بحياتي ومالي وأسرتي."**

The product is not a generic chatbot, marketplace, social network, or expense tracker. Its strategic core is the **NUS Financial Brain / Household CFO**.

## Engineering standards

- Real functionality before visual polish.
- User-entered facts remain authoritative.
- No fake production behavior.
- AI is an intelligence layer, not the source of truth.
- Provider credentials remain server-side.
- Financial writes require explicit user intent/confirmation where applicable.
- Preserve working behavior and prefer additive, reversible changes.
- Every meaningful feature must be implemented, integrated, tested, analyzed, CI-verified, and APK-verified when Android-facing.

## Repository

`Generalsea1/NUS.1.1.1`

## Version

`2.0.0+2`

## Build

GitHub Actions verifies Flutter analysis/tests and the Android workflow generates, verifies, and uploads a debug APK artifact.

## Release note

The repository is under controlled product development. Release hardening remains blocked until the external Supabase Auth leaked-password protection setting is enabled and the Financial Advisor is live-tested end-to-end against the production Gemini path.
