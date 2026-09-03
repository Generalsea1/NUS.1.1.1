# NOS — Product & Engineering Roadmap

## Quality rule
No phase is considered complete until the repository is internally reviewed and an automated build/analyze gate passes for that phase. No secrets are committed to Git.

## Phase 0 — Foundation
- [x] Repository verified: `Generalsea1/NUS.1.1.1`
- [x] Flutter project metadata created (`nos`, version `1.0.0+1`)
- [x] Arabic/English direction and copy established
- [x] CI workflow present for Flutter analyze + Android debug APK
- [ ] First green CI build

## Phase 1 — Schedule MVP (current)
- [ ] Reliable local persistence
- [ ] Add appointment/reminder with date + time
- [ ] Today and upcoming views
- [ ] Complete / undo
- [ ] Delete
- [ ] Arabic RTL + English LTR
- [ ] Notification permission + scheduled local notifications
- [ ] Automated tests for storage/model/business rules
- [ ] Green CI build + APK artifact verified

## Phase 2 — Expenses
- [ ] Income/expense entries
- [ ] Categories
- [ ] Monthly totals
- [ ] Search/filter
- [ ] Local-first storage
- [ ] Tests + CI gate

## Phase 3 — Shopping
- [ ] Shopping lists
- [ ] Check-off workflow
- [ ] Optional link from recipe to shopping list
- [ ] Tests + CI gate

## Phase 4 — Recipes
- [ ] Recipe search/input
- [ ] Ingredients, grams, servings, timers
- [ ] Recipe-to-shopping-list flow
- [ ] Arabic/English content model
- [ ] Tests + CI gate

## Phase 5 — Invoices & Debts
- [ ] Invoice records
- [ ] Customer/debtor records
- [ ] Amounts, due dates, status
- [ ] Reminders
- [ ] Tests + CI gate

## Phase 6 — Accounts, Sync & AI
- [ ] Optional Supabase authentication
- [ ] Secure sync/backup
- [ ] AI assistant layer behind a provider abstraction
- [ ] Cost controls and quotas
- [ ] Privacy/security review

## Release discipline
Versioning follows semantic intent: feature releases increase the minor version; fixes increase the patch version; Android build numbers increase for every distributable build.
