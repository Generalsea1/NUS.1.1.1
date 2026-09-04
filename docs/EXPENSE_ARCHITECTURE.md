# NUS — Expense Domain and Local Persistence

Phase 6.5.2 establishes the financially safe local foundation for Expenses.

## Money

`Money` is an immutable value object composed of:

- `minorUnits`: exact integer monetary value
- `currencyCode`: canonical ISO-style three-letter code

No floating-point value is persisted or used for Money. The foundation does not implement currency conversion or exchange rates. Minor-unit scale is an explicit currency/display concern and is not guessed from locale.

Currency validation in this phase is deliberately limited to the canonical three-letter ISO-style shape. A future currency registry may add membership/metadata rules without changing the stored integer-money representation.

## Expense date

`ExpenseDate` is a date-only value object containing year, month, and day. It has no time-of-day or timezone semantics. Serialization is always `YYYY-MM-DD`.

## Aggregate

`Expense` is the aggregate root. It contains Money, date, and optional category, merchant, description, and payment method values. Expense amounts must be strictly positive; Money itself is not globally positive-only so it remains reusable for future financial domains.

## Persistence

`LocalExpenseRepository` implements `ExpenseRepository` through `SharedPreferences` using the isolated key `nus.expenses.v1`.

The repository persists a deterministic JSON array. Individual malformed records are ignored so valid expenses remain recoverable. A malformed root payload is readable as an empty result, but save/delete refuse to overwrite that root and instead fail explicitly. Duplicate valid IDs are de-duplicated deterministically with the first valid record winning. Saving an existing ID replaces that record.

Repository ordering is deterministic by expense date ascending and then stable ID ascending.

## Boundaries

Expense domain code does not depend on UI, Budget, Analytics, AI, Supabase, notifications, reminders, authentication, or other feature domains. Budget and analytics may consume Expense data through future application/query boundaries. A future cloud adapter can implement the repository contract without changing the domain.
