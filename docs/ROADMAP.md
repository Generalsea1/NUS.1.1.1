# NUS 2.0 — Product & Engineering Roadmap

## Quality rule
No phase is considered complete until the repository is internally reviewed and an automated build/analyze gate passes for that phase. No secrets are committed to Git. Runtime-dependent release claims also require real runtime evidence.

## Current product direction
NUS is evolving from a collection of personal organizer tools into a personal + household life operating system. Its strategic core is the NUS Financial Brain / Household CFO:

`open NUS → see financial position → understand the pressure → act quickly → ask NUS when needed → return with better control`

## Phase 0 — Foundation
- [x] Repository verified: `Generalsea1/NUS.1.1.1`
- [x] Arabic/English direction and copy established
- [x] Supabase authentication and server-side AI boundaries established
- [x] CI workflow present for Flutter analyze + Flutter tests
- [x] Android APK build workflow present
- [ ] Final NUS 2.0 release artifact validated on target device

## Phase 1 — NUS Today / Daily Operating Surface
- [x] NUS Today promoted to authenticated home
- [x] Quick Add connected to the existing ScheduleStore and notification pipeline
- [x] Ask NUS entry point exposed from the current financial experience
- [x] Today reads real local reminders from the shared ScheduleStore
- [x] Complete / undo reminders directly from Today
- [x] Delete reminders directly from Today
- [x] Today combines appointments and reminders into a next-action view
- [x] Today reads live monthly spending from the existing expense service
- [x] Reminder-aware Daily Intelligence model added
- [x] Arabic voice capture in Quick Add
- [x] Deterministic Arabic natural date/time parsing for Quick Add
- [x] Notification controls reachable from Today
- [x] Unified action routing across reminder / appointment / expense / shopping intents
- [x] Household-wide daily brief
- [x] Proactive cross-domain recommendations

## Phase 2 — Money Operating Layer
- [x] Income sources
- [x] Expense records
- [x] Categories and currency model
- [x] Monthly actual totals and category analytics
- [x] Recurring expense definitions
- [x] Financial engine / household intelligence foundations
- [x] Cash-flow forecast
- [x] Installment planner UX
- [x] Debt planner UX
- [x] Subscription management
- [x] Affordability scenarios (“Can I afford this?”)
- [x] Anomaly and budget-pressure alerts
- [x] Household budget planning and AI-assisted budget management
- [x] Financial command-center presentation with actual position and spending pressure indicators

## Phase 3 — Smart Shopping
- [x] Shopping lists
- [x] Check-off workflow
- [x] Local lifecycle service
- [x] Quick Add integration
- [ ] Budget-aware shopping mode
- [x] Household sharing
- [ ] Recipe-to-shopping-list automation
- [x] Tests + CI gate for cross-domain flows

## Phase 4 — Recipes & Home Operations
- [ ] Recipe search/input
- [ ] Ingredients, grams, servings, timers
- [ ] Recipe-to-shopping-list flow
- [ ] Budget-aware meal planning
- [ ] Home maintenance schedules
- [ ] Warranty reminders

## Phase 5 — Household
- [x] Household members
- [x] Roles and permissions
- [x] Shared tasks foundation
- [x] Shared shopping lists
- [ ] Shared calendar / appointments
- [ ] Household notification preferences
- [x] Secure invitation/join flow foundation

## Phase 6 — Health & Personal Records
- [x] Medication lifecycle foundation
- [x] Medication reminders
- [ ] Refill planning
- [ ] Health routine layer
- [ ] Document expiry reminders
- [ ] Vehicle / insurance / warranty reminders

## Phase 7 — NUS Intelligence
- [x] Provider-neutral application boundary
- [x] Secure server-side AI boundary
- [x] AI quota / reservation foundations
- [x] Financial context composer for the advisor
- [x] User-facing **Ask NUS** financial conversation surface
- [x] Structured AI response: summary, facts, priorities, warnings
- [x] Provider/API-key setup removed from the active user experience
- [x] Proactive opening financial insight when reliable context is available
- [x] Explicit user confirmation for authoritative financial writes
- [x] Proactive appointment notifications
- [ ] Unified proactive notifications across reminders, money, shopping and health
- [ ] Quiet hours / frequency controls
- [ ] Explainable AI decisions with source data references
- [ ] Live production verification of Financial Advisor Gemini path

## Phase 8 — Globalization & Trust
- [x] Arabic RTL foundation
- [x] English LTR foundation
- [ ] Egypt localization pack
- [ ] Europe localization pack
- [ ] Multi-currency UX hardening
- [ ] Privacy center
- [ ] Data export / deletion controls
- [ ] Production security review
- [ ] Supabase Auth leaked-password protection enabled

## Release discipline
Semantic intent remains the release rule: feature releases increase the minor version, fixes increase the patch version, and Android build numbers increase for every distributable build. NUS 2.0 work must preserve the existing local-first and secure server-side AI boundaries.

## Current verified release gate
- Repository CI: current changes are required to pass analyze + test again after each functional change.
- Supabase Performance Advisor: foreign-key and auth-initplan findings remediated; remaining unused-index findings stay workload-gated.
- Supabase Security Advisor: one external warning remains — leaked-password protection is disabled.
- Financial Advisor: implementation, structured response contract, quota handling, and server-side Gemini boundary are present; a live authenticated Gemini response still requires real device/session verification.
- Android: the workflow builds a release APK and verifies processed manifest/icon resources; the current main build must finish successfully before a new distributable artifact is declared verified.
