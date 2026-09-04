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

The Finance transaction primitive implements this contract:

- amount is a non-zero signed integer in minor units;
- positive amount represents income/inflow;
- negative amount represents expense/outflow;
- currency is normalized to uppercase three-letter form;
- zero-value transactions are rejected.

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

Balances are derived from the account opening balance plus compatible transaction history. No independently mutable current-balance field is stored in the Account aggregate.

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

### 5.2 Phase 7.4 account balance / transaction integration

The implemented ledger foundation connects transactions to accounts by stable `FinancialTransaction.accountId` identity.

The balance equation is deterministic:

```text
Account Balance = openingBalanceMinorUnits + Σ transaction.amountMinorUnits
```

Because transaction amounts are signed integers:

- positive values increase the balance;
- negative values decrease the balance;
- no floating-point arithmetic is required;
- the Account aggregate does not store a mutable current balance.

The application/query boundary exposes:

- `balanceForAccount(accountId)`;
- `balanceMinorUnits(accountId)`;
- `transactionsForAccount(accountId)`.

Each transaction selected for an account must match the account currency exactly. A mismatch raises `AccountCurrencyMismatchException`; incompatible currencies are never silently summed.

Account archive/rename operations do not rewrite or delete historical transactions because transaction storage is independent and keyed by stable account ID.

The local transaction repository persists independently under `nus.finance.transactions.v1` and isolates malformed individual records.

### 5.3 Phase 7.5 transaction mutation boundary

Financial transaction creation and mutation are controlled by `FinancialTransactionMutationService` in the application layer.

Creation follows this sequence:

```text
createTransaction input
        ↓
FinancialTransaction domain validation
        ↓
Account lookup by stable ID
        ↓
Reject missing / archived account
        ↓
Exact currency compatibility check
        ↓
Duplicate transaction ID check
        ↓
FinancialTransactionRepository.save
```

The use case never accesses `SharedPreferences` directly and never bypasses the repository boundary.

New transactions may only target an active account. Updating an existing transaction preserves its stable transaction ID and existing account relationship; account-to-account movement is deliberately out of scope.

Update operations revalidate account existence and currency compatibility before repository persistence. Historical correction of a transaction already linked to an archived account is allowed without changing its account identity, while creation against an archived account is rejected.

Create requests that reuse an existing transaction ID are rejected with an explicit duplicate-ID exception rather than relying on repository upsert behavior. This prevents repeated create requests from silently replacing an existing financial record.

Destructive transaction deletion is not exposed by the mutation use case. The repository's low-level CRUD delete capability remains an infrastructure contract, but financial application flows must use an explicit future reversal/void policy before destructive history mutation is authorized.

Optional `categoryId` and `externalReference` values remain opaque references. No Category, Expense, Income, Bill, Subscription, or other future domain is coupled into the current mutation service.

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
The Phase 7.4 transaction repository uses `nus.finance.transactions.v1`.

No Supabase synchronization is part of the current Finance foundation slices.

## 17. Implementation slices

### 17.1 Financial transaction core — implemented / verification open

- stable transaction identity;
- stable account reference;
- exact signed minor-unit money representation;
- deterministic serialization;
- domain invariants.

### 17.2 Expense financial read boundary — implemented / verification open

Finance consumes existing Expense data through an application/query boundary. Expense does not import Finance.

### 17.3 Account aggregate + local repository — implemented / verification open

- stable account identity;
- bank/wallet/cash types;
- exact opening balance;
- archive semantics;
- dedicated local storage namespace.

### 17.4 Account balance / transaction integration — implemented / verification open

- stable transaction → account identity reference;
- dedicated transaction persistence;
- account-specific transaction queries;
- deterministic opening + signed transaction balance derivation;
- explicit currency mismatch failure;
- no stored mutable current balance;
- account rename/archive preserves historical transaction references.

### 17.5 Financial transaction creation / mutation use case — implemented / verification open

- controlled application-layer mutation entry point;
- account existence/active-state validation for creation;
- exact currency compatibility validation;
- duplicate-ID protection on create;
- stable transaction ID and account preservation on update;
- repository-only persistence;
- opaque category/source references preserved;
- destructive delete intentionally excluded pending an explicit reversal/void policy.

No account UI, ledger UI, cloud sync, budgets dashboard, or migration of Expenses is included.

## 18. Future implementation order

1. Financial categories + category repository.
2. Income capture and transaction application service, if not covered by the transaction mutation slice.
3. Budget aggregate/lifecycle and budget queries.
4. Bill and subscription application/data layers.
5. Debt tracking.
6. Savings goals.
7. Financial summaries/trends/dashboard.
8. Shared recurrence integration for recurring bills/subscriptions.

Each item receives its own inspect → plan → implement → test → verify → evidence gate.
