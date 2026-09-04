# NUS MASTER BACKLOG

Constitution: `docs/NUS_MASTER_PRODUCT_ARCHITECTURE_CONSTITUTION.md` v1.0
Baseline assessed: `c949e1e49d0790e4722da66552111f19cc208099`

Status vocabulary: `DONE` / `IN PROGRESS` / `BLOCKED` / `READY` / `FUTURE`.

## Portfolio status

| Phase | Status | Current scope |
|---|---|---|
| 1 — Schedule Foundation | DONE | Local schedule/reminders foundation and notification integration |
| 2 — Appointments | DONE | Local-first appointment management and reminder orchestration |
| 3 — Medications | DONE | Medication domain, local persistence, lifecycle and reminder integration |
| 4 — Shopping | DONE | Shopping aggregate, local persistence, lifecycle and UI |
| 5 — Recipes / legacy roadmap item | FUTURE | Recipe model/search and shopping generation |
| 6.1 — Core Domain | DONE | Shared domain/repository contracts and provider-neutral AI boundary |
| 6.2 — Appointments hardening | DONE | Appointment architecture and reminder boundaries |
| 6.3 — Medications | DONE | Medication lifecycle + reminder coordinator/adapter |
| 6.4 — Shopping | DONE | Shopping lifecycle + local repository + UI |
| 6.5 — Expenses | IN PROGRESS | Expense domain, lifecycle, local persistence, UI verification |
| 6.6 — Master Architecture Constitution | DONE | This constitution + master backlog |
| 7 — Financial System | READY | Budgets, income/expense queries, financial summaries, bills/debts |
| 8 — Tasks & Goals | FUTURE | Tasks, projects, goals, progress and recurrence composition |
| 9 — Notes & Universal Search | FUTURE | Notes, indexing, unified search and navigation |
| 10 — Home Manager | FUTURE | Household assets, maintenance, utilities and service records |
| 11 — NUS Intelligence | FUTURE | AI Gateway, context policy, retrieval and safe intelligence features |
| 12 — Automation Engine | FUTURE | User-defined rules, triggers, actions and auditability |
| 13 — Cloud / Sync | FUTURE | Supabase data plane, offline sync, conflict resolution and backup |
| 14 — Family / Shared | FUTURE | Ownership, membership, permissions and shared records |
| 15 — Security / Backup / Export | FUTURE | Vault, encryption, export/import, recovery and security hardening |
| 16 — Android Production Scaffold | FUTURE | Release-grade Android, signing, backup, notification and deployment policy |

## Phase 6.5 — Expenses

### 6.5.1 Expense domain and value objects — DONE

- `Money` exact integer minor units — DONE.
- Three-letter canonical currency shape — DONE.
- `ExpenseDate` date-only value object — DONE.
- `Expense` aggregate with stable ID and optional details — DONE.
- Explicit deterministic JSON representation — DONE.

### 6.5.2 Local persistence and lifecycle — DONE

- `ExpenseRepository` boundary — DONE.
- `LocalExpenseRepository` using `nus.expenses.v1` — DONE.
- Deterministic ordering — DONE.
- Malformed record/root handling — DONE.
- Lifecycle create/update/delete service — DONE.
- Stable edit ID preservation — IMPLEMENTED / VERIFICATION DEPENDENT.

### 6.5.3 Expense UI — DONE IMPLEMENTATION / VERIFICATION OPEN

- List/loading/empty/error states — DONE.
- Create form — DONE.
- Edit form — DONE.
- Delete confirmation/failure path — DONE.
- Save failure UX — IMPLEMENTED / VERIFICATION OPEN.
- Duplicate submission protection — IMPLEMENTED / VERIFICATION OPEN.
- Navigation during pending save — IMPLEMENTED / VERIFICATION OPEN.

### 6.5.4 Blocked Diagnostics — BLOCKED

Issue: Save interaction tests at c949 report a Flutter hit-test warning after `find.text('حفظ المصروف')` resolves one widget.

Known facts:

- Runtime root: `800×600`.
- Observed Text-target tap centers: `Offset(409.0, 608.0)` and `Offset(409.0, 546.6)`.
- c949 changed `_revealSave()` from one-shot drag to `dragUntilVisible` only.
- Three Expense UI tests failed in Run `33876238965`.
- `flutter analyze` passed.
- Full suite result: 260 passed, 3 failed.
- Root cause: NOT PROVEN.
- Best hypothesis: TEST TARGET MISMATCH — VERY HIGH CONFIDENCE.
- Candidate test-only change remains UNEXECUTED.

The blocked diagnostic must not block unrelated architecture/product work.

### 6.5.5 Final Expense acceptance — READY AFTER BLOCKER RESOLUTION

Acceptance gates:

- resolve/verify Save interaction target in the test environment;
- run the three affected tests;
- run focused Expense UI suite;
- run full suite;
- verify analyze;
- verify exact final SHA and diff;
- accept/reject Phase 6.5 only from evidence.

## Phase 6.6 — Constitution — DONE

- Master product vision — DONE.
- Domain map — DONE.
- Feature map — DONE.
- Dependency rules — DONE.
- Local-first policy — DONE.
- Repository/storage boundaries — DONE.
- Identity strategy — DONE.
- Cross-domain references/events — DONE.
- Recurrence target architecture — DONE.
- Notification/reminder architecture — DONE.
- Security/auth/AI boundaries — DONE.
- Vault / Supabase / Sync / Family future boundaries — DONE.
- Android requirements — DONE.
- DoD/testing/migration rules — DONE.
- Protected infrastructure — DONE.

## Phase 7 — Financial System

Status: READY. Do not implement until Phase 6.5 acceptance is closed unless an explicit architecture dependency requires a narrowly scoped prerequisite.

- Financial read/query model for Expenses — READY.
- Budget aggregate and lifecycle — READY.
- Monthly/category summaries — READY.
- Income support — READY.
- Bills/debts application/data layers — READY.
- Financial dashboard — FUTURE within Phase 7.
- Forecasting/planning engine — FUTURE.
- Currency conversion/exchange-rate service — FUTURE.

Rule: Finance consumes Expense information through application/query boundaries; Expenses must not depend on Finance.

## Phase 8 — Tasks & Goals

- Task aggregate — FUTURE.
- Project/grouping model — FUTURE.
- Goal aggregate — FUTURE.
- Progress tracking — FUTURE.
- Recurrence composition with central engine — FUTURE.
- Task reminders through shared notification boundary — FUTURE.

## Phase 9 — Notes & Universal Search

- Note application/data layers — FUTURE.
- Index/search contract — FUTURE.
- Cross-domain search projection — FUTURE.
- Universal search UI/navigation — FUTURE.
- Attachments — FUTURE.

## Phase 10 — Home Manager

- Home/asset domain — FUTURE.
- Maintenance records — FUTURE.
- Utility/service records — FUTURE.
- Household reminders — FUTURE.
- Home document attachments — FUTURE.

## Phase 11 — NUS Intelligence

- AI Gateway runtime — FUTURE.
- Context permission policy — FUTURE.
- Provider adapters — FUTURE.
- Local-model option — FUTURE.
- Retrieval/query interfaces — FUTURE.
- Audit and privacy controls — FUTURE.
- Cost/quota controls — FUTURE.

## Phase 12 — Automation Engine

- Trigger contract — FUTURE.
- Condition evaluation — FUTURE.
- Action contract — FUTURE.
- User-defined automation — FUTURE.
- Execution history/audit — FUTURE.
- Recurrence/event integration — FUTURE.

## Phase 13 — Cloud / Sync

- Supabase schema/migrations process — FUTURE.
- User-owned row policy/RLS — FUTURE.
- Local change log — FUTURE.
- Sync queue — FUTURE.
- Conflict resolution — FUTURE.
- Tombstones/deletion sync — FUTURE.
- Backup/restore — FUTURE.
- Multi-device validation — FUTURE.

No cloud synchronization is authorized by the current Constitution task.

## Phase 14 — Family / Shared

- Shared ownership model — FUTURE.
- Membership/roles — FUTURE.
- Permission matrix — FUTURE.
- Shared record lifecycle — FUTURE.
- Revocation/audit — FUTURE.
- Family privacy boundaries — FUTURE.

No Family/Shared functionality is authorized by the current Constitution task.

## Phase 15 — Security / Backup / Export

- Personal Vault domain — FUTURE.
- Encryption/key-management design — FUTURE.
- Secure export/import — FUTURE.
- Recovery workflow — FUTURE.
- Secret/credential scanning — FUTURE.
- Security audit and threat model — FUTURE.

## Phase 16 — Android Production Scaffold

The repository already contains an Android scaffold at the assessed baseline; this backlog item refers to production hardening, not creating a new Android project now.

- Release configuration — FUTURE.
- Signing and release keys outside source control — FUTURE.
- Backup policy — FUTURE.
- Notification permission/exact-alarm compliance — FUTURE.
- Deep links — FUTURE.
- Background execution policy — FUTURE.
- Production artifact verification — FUTURE.
- Store-release readiness — FUTURE.

## Unrelated-work policy

A BLOCKED item freezes only the dependent acceptance gate. It does not freeze documentation, architecture decisions, independent domain work, or verified non-dependent maintenance.

No workaround is allowed merely to change a status from BLOCKED to DONE.

## Immediate next implementation task

`6.5.5 — Final Expense acceptance`: once an execution-capable development environment is available, apply only the already-authorized minimal test target correction, verify the affected tests and full suite, and close/reject 6.5 from evidence. No production-layout rewrite is authorized.
