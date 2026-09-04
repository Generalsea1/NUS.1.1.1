# NUS — Financial System Architecture

Status: PHASE 7 DESIGN BASELINE
Constitution: `docs/NUS_MASTER_PRODUCT_ARCHITECTURE_CONSTITUTION.md` v1.0

## 1. Scope

Phase 7 turns the existing Expense capability into a broader personal financial system without making Expenses depend on Finance.

The financial system is local-first, exact-money, stable-identity, and explicitly bounded. Cloud sync, Family/Shared, AI automation, and Android production hardening remain future phases.

## 2. Financial domain map

```text
Financial Account
   ├── Bank Account
   ├── Wallet / Cash
   └── Future account types

Financial Category
   ├── Income categories
   └── Expense categories

Financial Transaction
   ├── Income
   └── Expense

Budget
Bill
Recurring Bill / Subscription
Debt
Savings Goal
```

`FinancialTransaction` is the ledger-level money movement. Expenses and future income records are product-domain records; their relationship to the ledger is expressed through application/query boundaries and source references rather than domain-to-domain imports.

## 3. Money model

All financial monetary values use integer minor units plus a three-letter canonical currency code.

No floating-point representation is permitted for persisted financial value.

Currency conversion is explicitly out of scope until a dedicated exchange-rate design exists.

The Finance transaction primitive now implemented follows this contract:

- amount is positive minor units;
- transaction type supplies direction (`income` or `expense`);
- `signedMinorUnits` is derived for cash-flow calculations;
- currency is normalized to uppercase three-letter form.

## 4. Identity

Every financial entity has a stable opaque application-owned ID.

IDs must not depend on:

- array position;
- display name;
- category text;
- amount;
- hash code;
- current date presentation.

Transaction IDs remain stable through edits and synchronization.

Account IDs are independent from transaction IDs.

## 5. Financial accounts

An Account represents a source or destination of money.

Initial account categories:

- bank account;
- wallet/cash;
- later: card, savings, investment or other explicitly modeled account types.

An account owns no transaction persistence directly in the domain; transactions reference `accountId`.

Future balances are derived from transactions and opening/adjustment entries rather than copied into unrelated feature records.

### 5.1 Phase 7.3 account aggregate baseline

The implemented Account aggregate establishes the minimum production foundation for bank accounts, wallets, and cash:

- stable opaque `id`;
- non-empty normalized display `name`;
- `AccountType.bank`, `AccountType.wallet`, or `AccountType.cash`;
- uppercase three-letter `currencyCode`;
- exact integer `openingBalanceMinorUnits`, including negative opening balances when required by the account state;
- explicit `isArchived` state;
- deterministic JSON serialization;
- value equality and `copyWith` semantics;
- archive operation that preserves identity.

The local repository persists accounts under `nus.finance.accounts.v1`. `deleteById` uses archive semantics rather than physically removing the account, preserving stable identity for future transaction history.

No current account balance is stored in the Account aggregate. Balance computation remains a future transaction-integration concern.

## 6. Categories

Categories are first-class financial identities.

A category has a stable ID, display name, direction/scope, and active state.

A transaction stores `categoryId` rather than embedding category objects.

Category deletion must be explicit: either archive the category or migrate references before destructive deletion is authorized.

## 7. Income and Expense

Income and Expense are transaction directions, not separate money representations.

Existing `Expense` remains authoritative for Expense capture and local persistence.

Future Finance integration must use an application/query boundary to project Expense records into financial summaries or ledger views. Finance must never make the Expense domain import Finance classes.

Income will receive a first-class application/domain model when its product behavior is implemented.

## 8. Cross-domain references

Required relationships are application-level or identity-based:

```text
Expense ───────► financial reporting/query
Bill ──────────► payment / expense relation
Subscription ──► recurring payment records
Income ────────► Account
Transaction ──► Account
Transaction ──► Category
```

A source record may keep an opaque source reference in a financial transaction. Ownership and lifecycle remain with the source domain.

## 9. Budgets

A Budget defines a planned monetary limit over a period and optional category scope.

Budget consumption is derived from qualifying transactions/expense queries. It is not duplicated as mutable spending state inside the Budget entity.

The existing placeholder `Budget` is domain scaffolding only and is not accepted as a complete Phase 7 implementation.

## 10. Bills, recurring bills and subscriptions

Bills represent obligations with due dates and payment state.

Recurring bills define recurrence intent; the central future Recurrence Engine is responsible for occurrence calculation. Notification delivery remains behind the protected reminder/notification boundary.

Subscriptions are recurring financial obligations with their own stable identity and cadence. They may generate bill/payment occurrences but do not own historical transaction records implicitly.

## 11. Debts

Debt tracking will distinguish principal/amount, direction (owed by user vs owed to user), counterpart identity, due expectations, and settlement history.

Debt records must not be implemented as free-form notes or as mutations of Expense rows.

## 12. Savings goals

Savings Goals express a target amount, currency, target date, and progress source.

Progress should be derived from qualifying account/transaction data instead of maintained as an independently drifting counter.

## 13. Financial summaries

Phase 7 summaries should be query models, not persistence aggregates.

Required queries include:

- monthly income;
- monthly expenses;
- net cash flow;
- category spending;
- upcoming payments;
- budget consumption;
- account balances;
- spending trends.

All summary results must preserve currency boundaries. No automatic aggregation across incompatible currencies is allowed.

## 14. Budget alerts

Budget alerts are application-level decisions based on query results and threshold policy.

Alert delivery must use the protected reminder/notification infrastructure. Finance must not import notification plugin APIs directly.

## 15. Net cash flow

For a single currency and reporting period:

```text
Net Cash Flow = Income - Expenses
```

At ledger level, this is equivalent to the sum of signed transaction minor units.

Cross-currency netting is prohibited until an explicit conversion policy exists.

## 16. Storage

Phase 7 repositories must use dedicated versioned namespaces and preserve local-first operation.

Finance persistence must not reuse:

- `nos.schedule.v1`;
- `nus.appointments.v1`;
- `nus.medications.v1`;
- `nus.shopping.v1`;
- `nus.expenses.v1`.

The Phase 7.3 Account repository uses `nus.finance.accounts.v1`.

No Supabase synchronization is part of the first Finance slice.

## 17. First implementation slice

The first Phase 7 implementation slice is the Finance transaction primitive:

- stable transaction identity;
- stable account reference;
- exact minor-unit money representation;
- explicit income/expense direction;
- category/source references as opaque IDs;
- deterministic serialization;
- domain tests for invariants and signed cash flow.

No account UI, ledger UI, cloud sync, budgets dashboard, or migration of Expenses is included in this slice.

## 18. Future implementation order

1. Financial transaction query/read boundary for Expense data.
2. Account aggregate + local repository.
3. Account balance / transaction integration.
4. Category aggregate + local repository.
5. Income capture and transaction application service.
6. Budget aggregate/lifecycle and budget queries.
7. Bill and subscription application/data layers.
8. Debt tracking.
9. Savings goals.
10. Financial summaries/trends/dashboard.
11. Shared recurrence integration for recurring bills/subscriptions.

Each item receives its own inspect → plan → implement → test → verify → evidence gate.
