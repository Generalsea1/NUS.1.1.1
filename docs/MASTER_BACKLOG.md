# NUS MASTER BACKLOG

Constitution: `docs/NUS_MASTER_PRODUCT_ARCHITECTURE_CONSTITUTION.md` v1.0
Baseline assessed: `c949e1e49d0790e4722da66552111f19cc208099`
Status vocabulary: `DONE` / `IN PROGRESS` / `BLOCKED` / `BLOCKED — ENVIRONMENT` / `READY` / `FUTURE` / `IMPLEMENTED / VERIFICATION OPEN` / `IMPLEMENTED / VERIFICATION OPEN — ENVIRONMENT BLOCKED`.

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
| 6.5 — Expenses | ACCEPTED WITH KNOWN BLOCKED DIAGNOSTIC | Expense implementation accepted; final Save interaction verification remains isolated and environment-blocked |
| 6.6 — Master Architecture Constitution | DONE | Constitution + master backlog |
| 7 — Financial System | IN PROGRESS | Financial architecture + transaction core + Expense read/query + Account + balance + controlled mutation foundations |
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
- Stable edit ID preservation — IMPLEMENTED; targeted runtime verification remains blocked by the known Save hit-test path.

### 6.5.3 Expense UI — DONE IMPLEMENTATION / VERIFICATION OPEN

- List/loading/empty/error states — DONE.
- Create form — DONE.
- Edit form — DONE.
- Delete confirmation/failure path — DONE.
- Save failure UX — IMPLEMENTED / BLOCKED — ENVIRONMENT for final runtime acceptance.
- Duplicate submission protection — IMPLEMENTED / BLOCKED — ENVIRONMENT for final runtime acceptance.
- Navigation during pending save — IMPLEMENTED / BLOCKED — ENVIRONMENT for final runtime acceptance.

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

The blocker does not freeze unrelated product architecture or implementation work.

### 6.5.5 Final Expense acceptance — ACCEPTED WITH KNOWN BLOCKED DIAGNOSTIC

Available static/source/runtime evidence supports the completed Expense domain, repository, lifecycle, persistence, UI state, error handling, and dependency boundaries. Runtime interaction items that require a new execution-capable environment remain explicitly blocked rather than treated as product defects.

Acceptance closure requirements when execution capability is restored:

- verify the Save interaction using the already-authorized test-only target correction;
- run the three affected UI interaction tests;
- run focused Expense UI tests;
- run full suite;
- verify analyze;
- verify exact final SHA and diff.

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

Status: IN PROGRESS.

### 7.0 Financial System Architecture — DONE

Reference: `docs/FINANCIAL_SYSTEM_ARCHITECTURE.md`.

- Money representation policy — DONE.
- Transaction identity policy — DONE.
- Account identity policy — DONE.
- Account / wallet / bank-account boundaries — DONE.
- Category boundary — DONE.
- Budget boundary — DONE.
- Bill / recurring bill / subscription boundaries — DONE.
- Debt and savings-goal boundaries — DONE.
- Financial summary/query strategy — DONE.
- Expense → Finance boundary — DONE.
- Bill → Expense relation policy — DONE.
- Subscription → Expense relation policy — DONE.
- Income → Account relation policy — DONE.
- Account → net cash flow model — DONE.

### 7.1 Financial Transaction Core — IMPLEMENTED / VERIFICATION OPEN

Implemented in `lib/features/finance/domain/financial_transaction.dart` with dedicated domain tests.

- Stable transaction ID — DONE.
- Stable account reference — DONE.
- Exact integer signed minor-unit amount — DONE.
- Explicit positive/negative transaction direction — DONE.
- Category/source opaque references — DONE.
- Deterministic serialization — DONE.
- Domain invariant tests — IMPLEMENTED / BLOCKED — ENVIRONMENT for execution.

### 7.2 Financial read/query model for Expenses — IMPLEMENTED / VERIFICATION OPEN

Implemented without changing Expense domain or storage:

- `FinancialExpenseSnapshot` read model — DONE.
- `FinancialExpenseReader` application boundary — DONE.
- Expense repository → Finance adapter — DONE.
- Monthly expense total by currency — DONE.
- Monthly category totals — DONE.
- Exact minor-unit aggregation — DONE.
- Cross-currency aggregation isolation — DONE.
- Query tests — IMPLEMENTED / BLOCKED — ENVIRONMENT for execution.

### 7.3 Account Aggregate + Local Repository — IMPLEMENTED / VERIFICATION OPEN — ENVIRONMENT BLOCKED

Implemented in:

- `lib/features/finance/domain/account.dart`
- `lib/features/finance/data/local_account_repository.dart`
- `test/account_test.dart`

Slice includes stable account identity, bank/wallet/cash types, exact opening balance, active/archived state, deterministic serialization, equality/copy semantics, `AccountRepository`, `nus.finance.accounts.v1` local persistence, malformed-record isolation, and archive semantics.

Focused tests are implemented but runtime execution remains environment-blocked.

### 7.4 Account Balance / Transaction Integration — IMPLEMENTED / VERIFICATION OPEN

Implemented in:

- `lib/features/finance/domain/financial_transaction.dart`
- `lib/features/finance/data/local_financial_transaction_repository.dart`
- `lib/features/finance/application/account_balance_query_service.dart`
- `test/financial_transaction_test.dart`
- `test/account_balance_query_test.dart`

Slice includes:

- Stable `FinancialTransaction.accountId` reference — DONE.
- Transaction repository boundary using `DomainRepository<FinancialTransaction>` — DONE.
- Dedicated local storage `nus.finance.transactions.v1` — DONE.
- Deterministic transaction ordering and update-by-ID — DONE.
- Malformed individual-record isolation — DONE.
- Account-specific transaction query — DONE.
- Balance = opening balance + signed transaction minor units — DONE.
- No mutable stored current-balance field — DONE.
- Explicit account/transaction currency mismatch exception — DONE.
- Account rename/archive leaves transaction identity/history intact — DONE.
- Focused tests — IMPLEMENTED / BLOCKED — ENVIRONMENT for execution.

No Expense dependency, Expense storage change, reminder infrastructure change, Supabase sync, Family/Shared, or Android change was introduced.

### 7.5 Financial Transaction Creation / Mutation Use Case — IMPLEMENTED / VERIFICATION OPEN

Implemented in:

- `lib/features/finance/application/financial_transaction_mutation_service.dart`
- `test/financial_transaction_mutation_test.dart`

Slice includes:

- Controlled application-layer creation entry point — DONE.
- Stable transaction/account IDs and domain validation — DONE.
- Account existence validation — DONE.
- Archived-account rejection for new transactions — DONE.
- Exact currency compatibility validation — DONE.
- Duplicate transaction-ID protection on create — DONE.
- Stable ID and account preservation on update — DONE.
- Repository-only persistence — DONE.
- Optional opaque category/source references preserved — DONE.
- No transaction-transfer logic — DONE.
- Destructive transaction delete intentionally excluded pending an explicit reversal/void policy — DONE.
- Focused tests — IMPLEMENTED / BLOCKED — ENVIRONMENT for execution.

No Expense dependency, Expense storage change, reminder infrastructure change, Supabase sync, Family/Shared, or Android change was introduced.

### 7.6 Financial Categories + Category Repository — READY
### 7.7 Income capture + application service — FUTURE
### 7.8 Budget aggregate/lifecycle + queries — FUTURE
### 7.9 Bills + subscriptions application/data — FUTURE
### 7.10 Debt tracking — FUTURE
### 7.11 Savings goals — FUTURE
### 7.12 Financial summaries/trends/dashboard — FUTURE
### 7.13 Central recurrence integration for recurring financial obligations — FUTURE

Rules:

- Finance consumes Expense data through application/query boundaries; Expenses never depend on Finance.
- No cross-currency aggregation without an explicit conversion policy.
- No Supabase sync in the current Phase 7 slices.
- No Family/Shared implementation in Phase 7 foundations.
- No changes to ScheduleStore, NotificationService, ReminderScheduler, or Android scaffold.

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

No cloud synchronization is authorized in the current implementation slices.

## Phase 14 — Family / Shared

- Shared ownership model — FUTURE.
- Membership/roles — FUTURE.
- Permission matrix — FUTURE.
- Shared record lifecycle — FUTURE.
- Revocation/audit — FUTURE.
- Family privacy boundaries — FUTURE.

No Family/Shared functionality is authorized in the current implementation slices.

## Phase 15 — Security / Backup / Export

- Personal Vault domain — FUTURE.
- Encryption/key-management design — FUTURE.
- Secure export/import — FUTURE.
- Recovery workflow — FUTURE.
- Secret/credential scanning — FUTURE.
- Security audit and threat model — FUTURE.

## Phase 16 — Android Production Scaffold

The repository already contains an Android scaffold. This phase is production hardening, not project generation now.

- Release configuration — FUTURE.
- Signing and release keys outside source control — FUTURE.
- Backup policy — FUTURE.
- Notification permission/exact-alarm compliance — FUTURE.
- Deep links — FUTURE.
- Background execution policy — FUTURE.
- Production artifact verification — FUTURE.
- Store-release readiness — FUTURE.

## Unrelated-work policy

A BLOCKED item freezes only the dependent acceptance gate. It does not freeze documentation, architecture decisions, or independent implementation work.

No workaround is allowed merely to change a status from BLOCKED to DONE.

## Immediate next implementation task

`7.6 — Financial Categories + Category Repository`.

7.5 runtime verification remains open until an execution-capable Flutter environment is available.
