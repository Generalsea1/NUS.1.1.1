# NUS 2.0 — Product & Engineering Roadmap

## Quality rule
No phase is considered complete until the repository is internally reviewed and an automated build/analyze gate passes for that phase. No secrets are committed to Git.

## Current product direction
NUS is evolving from a collection of personal organizer tools into a personal + household life operating system. The primary daily loop is:

`NUS Today → understand today → act quickly → connect life data → receive useful proactive guidance → return tomorrow`

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
- [x] NUS Copilot entry point connected to the existing AI Hub
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

## Phase 3 — Smart Shopping
- [x] Shopping lists
- [x] Check-off workflow
- [x] Local lifecycle service
- [x] Quick Add integration
- [ ] Budget-aware shopping mode
- [ ] Household sharing
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
- [ ] Household members
- [ ] Roles and permissions
- [x] Shared tasks foundation
- [ ] Shared shopping lists
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

## Phase 7 — NUS Copilot / Proactive Intelligence
- [x] Existing provider abstraction
- [x] Secure server-side provider boundary
- [x] AI history / connection settings foundation
- [x] AI quota / reservation foundations
- [x] Context-aware Copilot across Today + Money + Shopping + Household
- [x] Action proposals with explicit user confirmation for authoritative writes
- [ ] Proactive but user-controlled notifications
- [ ] Explainable AI decisions with source data references

## Phase 8 — Globalization & Trust
- [x] Arabic RTL foundation
- [x] English LTR foundation
- [ ] Egypt localization pack
- [ ] Europe localization pack
- [ ] Multi-currency UX hardening
- [ ] Privacy center
- [ ] Data export / deletion controls
- [ ] Production security review

## Release discipline
Semantic intent remains the release rule: feature releases increase the minor version, fixes increase the patch version, and Android build numbers increase for every distributable build. NUS 2.0 work must preserve the existing local-first and secure server-side AI boundaries.
