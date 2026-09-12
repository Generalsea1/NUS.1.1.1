# NUS — PROJECT MASTER CONTRACT

**Document ID:** NUS-MASTER-CONTRACT-001  
**Status:** MASTER / GOVERNING DOCUMENT  
**Authority:** Single Source of Truth for product and engineering execution  
**Repository:** `Generalsea1/NUS.1.1.1`  
**Default branch:** `main`  
**Current audited branch HEAD:** `21f0752081db22257208efcae5ef482aef8ae01e`  
**Last audit date:** 2026-09-12  

> This document governs future work. Historical plans and feature notes are subordinate to the verified current repository state and this contract.

---

## 1. PRODUCT VISION

NUS is an **AI Household Operating System**: a personal and household system that connects daily life, money, obligations, tasks, shopping, and future plans so the user can understand what matters now and decide what to do next.

The product is not a generic social network, generic marketplace, generic expense tracker, or chatbot. Its strategic core is the **NUS Financial Brain / Household CFO**.

Core promise:

> **"قل لي ماذا يحدث الآن، وماذا يجب أن أفعل بعد ذلك بحياتي ومالي وأسرتي."**

Product loop:

```text
USER
  ↓
NUS TODAY
  ↓
CURRENT STATE
  ↓
MONEY + HOUSEHOLD + TASKS + SHOPPING + LIFE
  ↓
UNDERSTAND
  ↓
PREDICT
  ↓
RECOMMEND
  ↓
USER CONFIRMS
  ↓
ACTION / PERSISTENCE
  ↓
PROACTIVE REMINDER
  ↓
RETURN / RETAIN
```

---

## 2. PRODUCT PRINCIPLES

1. **Product value before visual polish.**
2. **Real functionality before apparent completeness.**
3. **User-entered facts are authoritative.**
4. **AI is an intelligence layer, not the source of truth.**
5. **Local-first where practical.**
6. **Provider-neutral AI architecture.**
7. **Preserve working behavior.**
8. **Prefer additive and reversible changes.**
9. **No fake production behavior.**
10. **No feature is complete because its UI exists; integration and verification are required.**

---

## 3. INFORMATION ARCHITECTURE

```text
NUS
├── Authentication / Identity
├── Onboarding
├── TODAY
├── Finance
│   ├── Income
│   ├── Expenses
│   ├── Recurring Expenses
│   ├── Obligations / Bills
│   ├── Installments
│   ├── Debt
│   ├── Cashflow
│   ├── Budget
│   ├── Goals
│   └── Affordability / What-if
├── Household
│   ├── Members
│   ├── Roles
│   ├── Invitations
│   ├── Shared Tasks
│   └── Shared Shopping
├── Tasks / Appointments
├── Shopping
├── Life / Health
└── AI
    ├── Financial Advisor
    ├── Copilot
    ├── Proactive Intelligence
    └── Scenario Engine
```

---

## 4. SCREEN / PAGE MAP

### Entry and identity
- App bootstrap / startup
- Authentication gate
- Sign in / registration flows as currently implemented
- Session recovery / logout boundary

### Onboarding
- Country / region
- Currency
- Household size
- Adults / children
- Housing
- Income frequency / income snapshot
- Debt / recurring obligations
- Emergency target
- Budget snapshot

### Today
- Daily dashboard
- Daily financial snapshot
- Appointments / reminders
- Next action
- Proactive recommendations
- Quick Add / action entry where implemented

### Finance
- Finance overview
- Income sources
- Expense capture / ledger
- Recurring expenses
- Obligations / bills
- Installment plans
- Financial goals
- Future cashflow / forecast
- Affordability / scenario analysis (target)

### Household
- Household profile
- Members / roles
- Invitations
- Shared shopping
- Shared tasks

### AI
- AI hub / Copilot entry point
- Financial Advisor
- Provider connection boundary where applicable
- Diagnostics must expose truthful controlled failure information, never fake success

### Supporting life domains
- Appointments
- Medications / reminders
- Notes
- Settings

**Rule:** This is an architectural map, not permission to create every listed screen immediately. Only approved roadmap tasks may add UI.

---

## 5. FEATURE MAP AND TARGET CAPABILITY

### TODAY
Target: answer what matters today and what action should happen next.

### QUICK ADD
Target: accept natural-language / voice intent, show a confirmation preview when ambiguity exists, then persist through the existing approved lifecycle.

### FINANCIAL BRAIN
Target:
- understand income and obligations
- compute actual spending
- identify pressure points
- produce safe-spend guidance
- forecast near-term cashflow
- compare actual vs plan

### HOUSEHOLD CFO
Target:
- affordability decisions
- debt strategy
- emergency planning
- what-if scenarios
- explainable financial recommendations

### HOUSEHOLD OS
Target:
- members and roles
- shared/private boundaries
- shared tasks
- shared shopping
- household coordination

### SMART SHOPPING
Shopping is a household decision layer, not a generic marketplace in the current product phase.

### PROACTIVE INTELLIGENCE
NUS should proactively surface meaningful upcoming or risky events across money, tasks, shopping, appointments and life.

### LIFE OS
Later expansion: medication, health routines, documents, warranties, vehicle, recipes, maintenance and connected household workflows.

---

## 6. FLUTTER ARCHITECTURE

Current repository structure contains:

```text
lib/
├── core/
├── features/
├── main.dart
├── legacy_main.dart
└── notification_service.dart
```

Current feature areas include:

```text
ai
appointments
bills
expenses
finance
household
income
medications
notes
obligations
onboarding
settings
shopping
today
```

Layering rule:

```text
Presentation
    ↓
Application / Domain
    ↓
Repository contracts
    ↓
Data sources / adapters
```

Domain contracts must not be coupled directly to Flutter widgets, vendor SDKs, notification implementation details, or Supabase types unless the boundary explicitly requires an adapter.

---

## 7. CURRENT COMPOSITION ROOT

`lib/main.dart` is the current application composition root. It initializes Supabase, notifications, the legacy ScheduleStore, appointment synchronization, medication services, shopping lifecycle, expense lifecycle and expense management, then injects them into the authenticated app shell.

This makes `lib/main.dart`, `legacy_main.dart`, and `notification_service.dart` protected integration points.

Do not rewrite the composition root merely for style.

---

## 8. LOCAL-FIRST AND STATE

Approved principle:

```text
UI
 ↓
Application state
 ↓
Repository
 ↓
Local or remote implementation
```

Existing reminder behavior uses the local ScheduleStore / SharedPreferences path and NotificationService. It must not be broken by changes to authentication, finance, AI, or household features.

SharedPreferences may be used for lightweight local state. Complex financial authoritative records remain behind their domain/repository contracts and approved persistence layer.

---

## 9. DATABASE — VERIFIED CURRENT SHAPE

The current Supabase database contains the following major tables:

```text
user_ai_connections
user_ai_runs
household_profiles
income_sources
obligations
recurring_expense_definitions
expense_records
ai_daily_quota
ai_quota_reservations
households
household_members
household_shopping_lists
household_shopping_items
household_invitations
installment_plans
household_tasks
```

Key relationships:

```text
auth.users
  ├── household_profiles
  ├── income_sources
  ├── obligations
  ├── expense_records
  ├── recurring_expense_definitions
  ├── installment_plans
  ├── user_ai_connections
  ├── user_ai_runs
  ├── ai_daily_quota
  └── ai_quota_reservations

households
  ├── household_members
  ├── household_profiles
  ├── household_invitations
  ├── household_shopping_lists
  └── household_tasks

household_shopping_lists
  └── household_shopping_items

obligations
  └── expense_records (optional obligation link)

recurring_expense_definitions
  └── expense_records (optional recurring link)
```

All currently inspected public tables have RLS enabled.

### Financial data authority

- `household_profiles`: household financial snapshot/configuration.
- `income_sources`: recurring income facts.
- `obligations`: future commitments.
- `expense_records`: actual expense ledger.
- `recurring_expense_definitions`: recurring expense definitions.
- `installment_plans`: installment structures.

AI output must not overwrite the authoritative financial ledger merely because the model produced a recommendation.

---

## 10. DATABASE CHANGE CONTROL

No destructive schema change is permitted without explicit approval.

Any schema change requires:

```text
Reason
→ Migration
→ Data impact
→ RLS impact
→ Application impact
→ Rollback consideration
→ Tests
→ Verification
```

Never edit production schema ad hoc when a migration is the proper mechanism.

---

## 11. AUTHENTICATION AND AUTHORIZATION

Application identity and AI/provider authorization are separate contracts.

Authentication is handled through Supabase Auth boundaries.

Household access must be constrained by:

```text
Authenticated identity
+
household membership
+
role
+
RLS
```

Current household roles:

```text
owner
admin
member
```

No provider credential must be placed in the Flutter application.

---

## 12. BACKEND / EDGE FUNCTIONS

Current Supabase Edge Functions verified:

```text
household-budget-ai    ACTIVE v8   verify_jwt=true
ai-provider-connect    ACTIVE v5   verify_jwt=true
financial-advisor-ai   ACTIVE v11  verify_jwt=true
nus-copilot-ai         ACTIVE v1   verify_jwt=true
```

Backend boundaries must remain authenticated unless a documented, justified exception exists.

---

## 13. AI ARCHITECTURE

AI must remain provider-neutral at the app/domain boundary.

```text
Flutter / Application
        ↓
AI contract / provider abstraction
        ↓
Authenticated Edge Function
        ↓
Provider
        ↓
Structured response
        ↓
Server validation
        ↓
Client rendering
```

Current financial advisor behavior includes:
- JWT authentication
- daily quota reservation / release / finalization
- server-side Gemini API key
- bounded context input
- structured JSON contract
- provider error diagnostics
- timeout handling
- response shape validation

AI must not:
- invent user financial facts
- change authoritative financial data without explicit user confirmation
- execute destructive actions by inference
- expose provider keys or tokens

---

## 14. SECURITY CONTRACT

Never:
- commit secrets
- put provider API keys in mobile source
- log access/refresh/provider secrets
- trust client-provided authorization claims without server validation
- weaken RLS to simplify UI development
- bypass authentication for convenience

Current security audit found warnings requiring follow-up:

1. `public.can_manage_household(target_household_id uuid)` has been moved behind a private helper and is no longer exposed as an anonymous executable SECURITY DEFINER API surface.
2. `public.accept_household_invitation(invite_token text)` now delegates to a private helper; the public RPC is invoker-scoped and anonymous execution is revoked.
3. Supabase Auth leaked-password protection is disabled.

The first two issues were remediated and re-verified. The leaked-password protection finding remains an external Auth configuration blocker.

---

## 15. PERFORMANCE CONTRACT

Current Supabase performance audit identified:

- 8 foreign keys without covering indexes.
- 16 RLS policies with per-row `auth`/`current_setting()` evaluation patterns flagged for optimization.
- 13 indexes reported as unused at the current observed scale.

These findings must be triaged before release hardening. Unused-index findings must not trigger blind deletion because the dataset is currently small.

Preferred rule:

```text
measure → understand workload → change → verify
```

---

## 16. UI / UX CONTRACT

NUS must be:

```text
Clear
Fast
Calm
Professional
Trustworthy
Consistent
RTL/LTR correct
Arabic/English first-class
```

Rules:
- no UI element exists merely for decoration
- no fake metrics
- no placeholder production actions
- no meaningless dashboard cards
- no AI theater
- important financial decisions must be understandable
- errors must tell the truth
- loading states must not imply success
- empty states must reflect real absence of data

---

## 17. PRODUCTION INTEGRITY

The system must never pretend something succeeded when it did not.

Forbidden fake production behavior includes:

```text
fake users
fake statistics
fake notifications
fake social interactions
fake analytics
fake AI responses
fake payments
fake database records
fake API responses
fake success states
```

Test doubles are permitted in automated tests only when they are explicitly scoped as test infrastructure and cannot leak into production execution.

---

## 18. TESTING STRATEGY

A completed feature may require, as applicable:

```text
Unit tests
Domain tests
Repository/integration tests
Widget/UI tests
Regression tests
Analyzer
CI
Android APK build + verification
```

Existing repository verification workflow runs:

```text
flutter pub get
flutter analyze
flutter test
```

on the relevant push/PR paths.

A passing UI test is not sufficient evidence for a backend-backed feature.

---

## 19. QUALITY GATE

No task is DONE until:

```text
IMPLEMENT
→ TEST
→ VERIFY
→ FIX
→ RETEST
→ REPORT
```

For Android-facing work:

```text
IMPLEMENT
→ TEST
→ ANALYZE
→ BUILD
→ APK VERIFY
→ REPORT
```

Phase completion requires all critical checks to pass.

---

## 20. PHASE ROADMAP

### PHASE 1 — PROJECT AUDIT
Goal: establish factual baseline and blockers.

### PHASE 2 — MASTER ARCHITECTURE
Goal: align feature boundaries, contracts and dependencies with the product North Star.

### PHASE 3 — REAL DATABASE
Goal: harden schema, RLS, indexes and authoritative data model.

### PHASE 4 — AUTHENTICATION & SECURITY
Goal: production-grade identity, authorization and credential handling.

### PHASE 5 — BACKEND & APIs
Goal: coherent, validated, observable service contracts.

### PHASE 6 — MOCK DATA ELIMINATION
Goal: prove all production paths use real persistence/services.

### PHASE 7 — CORE PRODUCT FEATURES
Goal: Today + Financial Brain + Household workflows provide real daily value.

### PHASE 8 — AI SYSTEMS
Goal: harden Advisor/Copilot/proactive/scenario intelligence with explicit boundaries.

### PHASE 9 — SOCIAL / CREATOR SYSTEMS
Only approved niche social/creator functionality that strengthens household/product value; never a generic social network by default.

### PHASE 10 — UX / UI POLISH
Only after functionality and stability gates pass.

### PHASE 11 — TESTING / QA
Full regression, integration, release candidate validation.

### PHASE 12 — PERFORMANCE / SCALABILITY
Query/index/RLS/API/UI performance under realistic workloads.

### PHASE 13 — PRODUCTION HARDENING
Security, monitoring, failure recovery, backup/recovery, release controls.

### PHASE 14 — FINAL RELEASE AUDIT
Independent verification that product claims match actual behavior.

---

## 21. PHASE 1 — CURRENT AUDIT STATE

### Verified
- Repository exists and is active.
- `main` currently points to `21f0752081db22257208efcae5ef482aef8ae01e`.
- Flutter package version is `2.0.0+2`.
- Current app has `main.dart` plus `legacy_main.dart` composition boundaries.
- Core and feature architecture exists.
- Supabase database and Edge Functions are active.
- Current database tables have RLS enabled.
- Verification workflow includes analyze + test.
- Household invitation authorization hardening is applied and verified.

### Observed / requires follow-up
- README still describes the application as `NUS v1.0.0` while `pubspec.yaml` is `2.0.0+2`.
- Historical master-plan documents exist and are not themselves authoritative.
- Android CI must reach Analyze, Test, Build debug APK, Verify APK and Upload APK successfully before the Phase 1 Android gate is green.
- Security advisor currently reports one warning: Supabase Auth leaked-password protection is disabled.
- Performance advisor reports index/RLS optimization findings described above.
- Repository search finds test doubles such as `SharedPreferences.setMockInitialValues`; these are test-scoped findings and must not be treated as production mocks without path/runtime verification.
- `main` remains unprotected with no required status checks; this is a governance/release-control follow-up, not a reason to alter branch policy blindly during Phase 1.

### Phase 1 status

**BLOCKED / IN PROGRESS**

Reason: the Auth leaked-password protection finding remains unresolved and the current Android CI gate has not yet produced verified APK evidence.

---

## 22. PROTECTED AREAS

No unapproved broad rewrite of:

```text
lib/main.dart
lib/legacy_main.dart
lib/notification_service.dart
lib/core/**
financial domain contracts / calculations
expense lifecycle / ledger
installment logic
household authorization / RLS
Supabase migrations
Edge Function authentication and quota boundaries
```

Protected does not mean immutable; it means **change only with evidence and explicit task scope**.

---

## 23. CHANGE CONTROL

For any change affecting Architecture, Database, API contracts, Authentication, Security, Navigation, or Major UX, record:

```text
1. Reason
2. Files / tables / functions affected
3. Dependencies
4. Alternatives considered
5. Risks
6. Rollback path
7. Verification plan
8. Documentation impact
```

Then implement only the minimum necessary change.

---

## 24. NON-DESTRUCTIVE RULE

```text
PRESERVE
→ VERIFY
→ MODIFY ONLY WHAT IS NECESSARY
→ TEST
→ VERIFY AGAIN
```

No rewrite merely because code can be cleaner.

---

## 25. NO-GUESSING RULE

If a fact is unknown:

```text
INSPECT FIRST.
```

Never guess files, APIs, schemas, dependencies, credentials, runtime behavior, or completion status.

---

## 26. AGENT EXECUTION CONTRACT

Every Agent working on NUS must:

```text
READ CONTRACT
→ INSPECT CURRENT STATE
→ DEFINE CHANGE BOUNDARY
→ IMPLEMENT
→ TEST
→ FIX
→ VERIFY
→ DOCUMENT
→ REPORT
```

The Agent may not silently redefine the product or advance to the next phase when the current gate is red.

Work one task at a time, but a task may legitimately touch multiple related files.

---

## 27. REQUIRED TASK REPORT

Every completed task must report:

```text
TASK:
STATUS:
FILES CHANGED:
WHAT CHANGED:
TESTS:
VERIFICATION:
RISKS:
NEXT TASK:
```

Use facts only. Never claim runtime, CI, build, or integration success without evidence.

---

## 28. DEFINITION OF DONE

```text
DESIGNED
+
IMPLEMENTED
+
INTEGRATED
+
TESTED
+
ANALYZED
+
CI VERIFIED
+
RUNTIME VERIFIED WHERE APPLICABLE
+
APK VERIFIED WHEN ANDROID-FACING
=
DONE
```

---

## 29. PRODUCT PRIORITY

When choosing the next approved capability, prefer the one with the highest combination of:

```text
User Value
Daily Frequency
Financial / Practical Impact
Retention Potential
Differentiation
```

Do not optimize roadmap order for ease of coding.

---

## 30. RELEASE STANDARD

Release quality is measured by:

```text
CORRECTNESS
SECURITY
REAL FUNCTIONALITY
USER VALUE
RELIABILITY
SCALABILITY
MAINTAINABILITY
PERFORMANCE
UX QUALITY
DIFFERENTIATION
```

"Looks finished" is not a release criterion.

---

## 31. CHANGE LOG

### 2026-09-12 — v1 of PROJECT MASTER CONTRACT
- Established this document as the governing source of truth.
- Audited current repository HEAD.
- Audited current Flutter structure and composition root.
- Audited current Supabase tables, migrations, Edge Functions and security/performance advisories.
- Recorded current blockers instead of marking Phase 1 complete.

### 2026-09-12 — security audit continuation
- Moved household authorization helper execution behind the private schema boundary.
- Hardened household invitation RPC execution so the public function is invoker-scoped while authenticated access remains available through the private helper.
- Recorded the remaining Auth leaked-password protection finding as an external configuration blocker.
- Recorded that Android CI must reach APK verification before the Phase 1 gate can close.
- Synchronized this contract with the actual current repository HEAD.

Future changes to architecture, schema, API, authentication, security, navigation or major UX must append a dated entry here.
