# NUS — PROJECT MASTER CONTRACT

**Document ID:** NUS-MASTER-CONTRACT-001  
**Status:** MASTER / GOVERNING DOCUMENT  
**Authority:** Single Source of Truth for product and engineering execution  
**Repository:** `Generalsea1/NUS.1.1.1`  
**Default branch:** `main`  
**Current audited branch HEAD:** `c15b96dbe462d8375ad182d9dd516697dc280908`  
**Last audit date:** 2026-09-12  

> This document governs future work. Historical plans and feature notes are subordinate to the verified current repository state and this contract.

---

## 1. PRODUCT VISION

NUS is an **AI Household Operating System**: a personal and household system connecting daily life, money, obligations, tasks, shopping, and future plans so the user can understand what matters now and decide what to do next.

The strategic core is the **NUS Financial Brain / Household CFO**.

NUS is not a generic social network, generic marketplace, generic expense tracker, or chatbot.

Core promise:

> **"قل لي ماذا يحدث الآن، وماذا يجب أن أفعل بعد ذلك بحياتي ومالي وأسرتي."**

Core loop:

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
RETURN
```

---

## 2. PRODUCT PRINCIPLES

1. Product value before visual polish.
2. Real functionality before apparent completeness.
3. User-entered facts are authoritative.
4. AI is an intelligence layer, not the source of truth.
5. Local-first where practical.
6. Provider-neutral AI architecture.
7. Preserve working behavior.
8. Prefer additive and reversible changes.
9. No fake production behavior.
10. A feature is not complete because its UI exists; integration and verification are required.

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

### Entry / Identity
- Bootstrap / startup
- Authentication gate
- Sign in / registration
- Session recovery / logout boundary

### Onboarding
- Country / region
- Currency
- Household size
- Adults / children
- Housing
- Income snapshot
- Debt / recurring obligations
- Emergency target
- Budget snapshot

### Today
- Daily dashboard
- Financial snapshot
- Appointments / reminders
- Next action
- Proactive recommendations
- Quick Add where implemented

### Finance
- Finance overview
- Income sources
- Expense ledger
- Recurring expenses
- Obligations / bills
- Installments
- Financial goals
- Future cashflow / forecast
- Affordability / scenarios (target)

### Household
- Household profile
- Members / roles
- Invitations
- Shared shopping
- Shared tasks

### AI
- AI hub / Copilot
- Financial Advisor
- Provider connection boundary
- Controlled diagnostics / truthful error states

### Supporting domains
- Appointments
- Medications / reminders
- Notes
- Settings

This map does not authorize implementation of every screen immediately.

---

## 5. FEATURE MAP

### TODAY
Answer what matters today and what action should happen next.

### QUICK ADD
Natural-language / voice intent → preview when ambiguous → confirmed persistence through existing lifecycle.

### FINANCIAL BRAIN
Income + expenses + obligations + installments + budget + cashflow → safe-spend, pressure, forecast and actual-vs-plan guidance.

### HOUSEHOLD CFO
Affordability, debt strategy, emergency planning, what-if scenarios, explainable financial recommendations.

### HOUSEHOLD OS
Members, roles, privacy boundaries, shared tasks and shared shopping.

### SMART SHOPPING
Household decision layer, not a generic marketplace.

### PROACTIVE INTELLIGENCE
Meaningful upcoming or risky events across money, tasks, shopping, appointments and life.

### LIFE OS
Later expansion: medication, health routines, documents, warranties, vehicle, recipes and maintenance.

---

## 6. FLUTTER ARCHITECTURE

Current structure:

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

Layering:

```text
Presentation
    ↓
Application / Domain
    ↓
Repository contracts
    ↓
Data sources / adapters
```

Domain contracts must not depend directly on vendor SDKs or UI framework details unless an adapter boundary explicitly requires it.

---

## 7. PROTECTED COMPOSITION ROOTS

`lib/main.dart`, `lib/legacy_main.dart`, and `lib/notification_service.dart` are protected integration points.

`main.dart` currently initializes Supabase, notifications, the legacy ScheduleStore, appointments, medications, shopping, expenses and expense management before creating the authenticated application shell.

No broad rewrite merely for style.

---

## 8. LOCAL-FIRST / STATE

```text
UI
 ↓
Application state
 ↓
Repository
 ↓
Local or remote implementation
```

Reminder behavior remains based on the existing ScheduleStore / SharedPreferences and NotificationService path.

SharedPreferences is for lightweight local state; authoritative complex financial records remain behind the approved domain/repository persistence layer.

---

## 9. DATABASE — VERIFIED CURRENT SHAPE

Current major tables:

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

Relationships:

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
  └── expense_records

recurring_expense_definitions
  └── expense_records
```

All inspected public tables have RLS enabled.

Financial authority:
- `household_profiles`: household financial snapshot/configuration.
- `income_sources`: recurring income facts.
- `obligations`: future commitments.
- `expense_records`: actual expense ledger.
- `recurring_expense_definitions`: recurring expense definitions.
- `installment_plans`: installment structures.

AI output never becomes the authoritative ledger merely because a model produced it.

---

## 10. DATABASE CHANGE CONTROL

No destructive schema change without explicit approval.

Every schema change requires:

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

---

## 11. AUTHENTICATION / AUTHORIZATION

Identity and AI/provider authorization are separate contracts.

Household access requires:

```text
Authenticated identity
+
Household membership
+
Role
+
RLS
```

Roles:

```text
owner
admin
member
```

Provider credentials never belong in Flutter source.

---

## 12. BACKEND / EDGE FUNCTIONS

Verified current functions:

```text
household-budget-ai    ACTIVE v8   verify_jwt=true
ai-provider-connect    ACTIVE v5   verify_jwt=true
financial-advisor-ai   ACTIVE v11  verify_jwt=true
nus-copilot-ai         ACTIVE v1   verify_jwt=true
```

Backend endpoints remain authenticated unless a documented exception is approved.

---

## 13. AI CONTRACT

```text
Flutter / Application
        ↓
AI Contract / Provider Abstraction
        ↓
Authenticated Edge Function
        ↓
Provider
        ↓
Structured Response
        ↓
Server Validation
        ↓
Client
```

Current financial advisor includes JWT authentication, quota reservation/release/finalization, server-side Gemini key, bounded context, structured JSON output, provider diagnostics, timeout handling and response validation.

AI must not invent financial facts, overwrite authoritative data without explicit user confirmation, execute destructive actions by inference, or expose provider secrets.

---

## 14. SECURITY

Never:
- commit secrets
- place provider API keys in mobile source
- log provider tokens
- weaken RLS for UI convenience
- bypass authentication

### Security findings and disposition — 2026-09-12

1. **FIXED:** anonymous execute access to `public.can_manage_household(uuid)` was removed.
2. **FIXED:** `can_manage_household` was moved to private schema `private.can_manage_household(uuid)`, its public function was removed, and the `household_member_update_admin` RLS policy now calls the private helper.
3. **REMAINING / INTENTIONAL:** `public.accept_household_invitation(text)` remains `SECURITY DEFINER` and callable by `authenticated` because the Flutter household invitation repository invokes this RPC directly. Replacing this with a private function would require a separate backend/API migration and is not to be done opportunistically during Phase 1.
4. **REMAINING EXTERNAL CONFIGURATION:** Supabase Auth leaked-password protection is disabled. This is a hosted Auth configuration item, not a database function setting. It must be enabled in the Supabase Auth password-security settings before the Phase 1 security gate can be green. Supabase documents this control in Auth password security. 

The current remaining security warnings are therefore explicit, known and not hidden.

---

## 15. PERFORMANCE

Current advisory baseline identified:
- 8 foreign keys without covering indexes.
- 16 RLS policies with per-row auth/current_setting evaluation patterns flagged for optimization.
- 13 indexes reported as unused at current observed scale.

These are recorded for the dedicated performance/schema hardening phases. No blind index deletion is permitted.

---

## 16. UI / UX

NUS must be clear, fast, calm, professional, trustworthy, consistent and correct for RTL/LTR.

No decorative metrics, fake states, AI theater, meaningless cards or placeholder production actions.

Important financial decisions must be understandable.

Errors must tell the truth.

---

## 17. PRODUCTION INTEGRITY

Forbidden in production:

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

Test doubles are allowed only inside test infrastructure and must not leak into production paths.

---

## 18. TESTING / QUALITY GATE

Completed work follows:

```text
IMPLEMENT
→ TEST
→ VERIFY
→ FIX
→ RETEST
→ REPORT
```

For Android-facing changes:

```text
IMPLEMENT
→ TEST
→ ANALYZE
→ BUILD
→ APK VERIFY
→ REPORT
```

The repository verification workflow currently runs `flutter pub get`, `flutter analyze`, and `flutter test`.

---

## 19. PHASE ROADMAP

1. Project Audit
2. Master Architecture
3. Real Database
4. Authentication & Security
5. Backend & APIs
6. Mock Data Elimination
7. Core Product Features
8. AI Systems
9. Social / Creator Systems (only where product-approved)
10. UX / UI Polish
11. Testing / QA
12. Performance / Scalability
13. Production Hardening
14. Final Release Audit

No phase advances while its critical gate is red.

---

## 20. PHASE 1 CURRENT STATE — 2026-09-12

### VERIFIED
- Repository active.
- `main` advanced from the original audit HEAD through the master-contract and security migrations.
- Flutter package version `2.0.0+2`.
- Core/feature architecture present.
- Supabase database active and healthy.
- Inspected public tables use RLS.
- Four current Edge Functions verified active with JWT enforcement.
- GitHub `Verify NUS PR` workflow run **34688183994** for the master-contract commit completed **successfully**. Its `Analyze` and `Test` steps both passed.
- Supabase security advisory no longer reports anonymous execution of `can_manage_household`.

### FIXED DURING PHASE 1
- Removed anonymous access to the household-management helper.
- Isolated `can_manage_household` into the private schema so it is no longer a public RPC surface.
- Preserved the existing RLS authorization behavior.
- Added the matching migration to the repository.

### REMAINING BLOCKER
**Supabase Auth leaked-password protection is still disabled.** This cannot be changed through the current database/Edge Function tooling because it is a hosted Auth configuration control.

Phase 1 therefore remains:

**BLOCKED — SECURITY CONFIGURATION PENDING**

No Phase 2 entry is authorized until this setting is enabled and the security advisor is re-run with evidence.

### NON-BLOCKING AUDIT ITEMS
- README version text is historical and should be aligned later under documentation cleanup.
- Performance advisor findings remain recorded for the appropriate database/performance phase.
- Test doubles discovered by repository search are confined to test files and are not evidence of production mocks by themselves.

---

## 21. PROTECTED AREAS

No unapproved broad rewrite of:

```text
lib/main.dart
lib/legacy_main.dart
lib/notification_service.dart
lib/core/**
financial contracts / calculations
expense lifecycle / ledger
installment logic
household authorization / RLS
Supabase migrations
Edge Function auth and quota boundaries
```

Protected means change only with evidence and explicit task scope.

---

## 22. CHANGE CONTROL

For changes affecting Architecture, Database, API contracts, Authentication, Security, Navigation, or Major UX, record:

```text
Reason
Files / tables / functions affected
Dependencies
Alternatives
Risks
Rollback path
Verification plan
Documentation impact
```

Then implement only the minimum required change.

---

## 23. NO-GUESSING RULE

Unknown fact → inspect first.

Never guess files, APIs, schemas, dependencies, credentials, runtime behavior or completion state.

---

## 24. AGENT EXECUTION CONTRACT

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

One task at a time. A task may touch multiple related files when required.

Never silently redefine the product.

---

## 25. REQUIRED REPORT

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

Facts only. No runtime, CI, build or integration success may be claimed without evidence.

---

## 26. DEFINITION OF DONE

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

## 27. CHANGE LOG

### 2026-09-12 — v1
- Created the governing NUS Project Master Contract.
- Established the product direction around the AI Household Operating System / Household CFO.
- Audited repository, Flutter architecture, Supabase schema, migrations, Edge Functions, CI and advisories.

### 2026-09-12 — Phase 1 security hardening
- Removed anonymous execution of `can_manage_household`.
- Moved household-management authorization helper to private schema.
- Updated the household-member RLS policy to use the private helper.
- Added repository migration `20260912102910_isolate_household_management_helper_from_api.sql`.
- Recorded the remaining hosted Auth leaked-password-protection setting as an explicit Phase 1 blocker.
- Recorded successful CI evidence for the master-contract commit.
