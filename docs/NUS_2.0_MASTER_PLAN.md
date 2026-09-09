# NUS 2.0 — Master Product & Engineering Plan

## Product North Star

NUS is not a bundle of utilities. It is a Personal + Household Life Operating System that helps a user understand and act on what is happening in life today.

Core loop:

```text
USER
  ↓
"ماذا يحدث في حياتي اليوم؟"
  ↓
NUS TODAY
  ↓
TASK / APPOINTMENT / MONEY / SHOPPING / HEALTH
  ↓
NUS CONNECTS THEM
  ↓
AI UNDERSTANDS THEM
  ↓
NUS TAKES ACTION
  ↓
PROACTIVE REMINDER
  ↓
USER RETURNS TOMORROW
```

## Non-negotiable engineering rules

1. Never replace or remove an existing feature merely to add a new feature unless its behavior is preserved or explicitly migrated.
2. Preserve public constructor contracts used by composition roots and navigation layers.
3. Inspect existing domain/application/repository APIs before integrating a feature.
4. Financial actions must never be inferred into a destructive or persistent write without clear user confirmation.
5. AI must be provider-abstracted and must not require the end user to paste a personal Gemini/OpenAI key into the mobile app.
6. Keep local-first behavior wherever practical; synchronize only through existing approved repositories/services.
7. Every product phase requires automated analyzer + test validation. Android APK work additionally requires a successful build and APK verification.
8. Do not mark a roadmap item complete based on UI presence alone. Completion means implementation + integration + tests + CI/build verification.
9. Never commit secrets, personal credentials, or provider keys.
10. Prefer additive, reversible changes over broad rewrites.

## Phase 1 — Daily Addiction

### P1. NUS Today
- [x] Unified daily dashboard surface.
- [x] Daily financial snapshot.
- [x] Daily appointment/reminder intelligence.
- [x] Next-action surface.
- [ ] Add stronger obligation/task unification.
- [ ] Add actionable recommendations based on multiple domains.

### P2. Universal Quick Add
- [x] Natural-language reminder parsing.
- [x] Arabic/Egyptian voice input path.
- [x] Intent classifier foundation (reminder/shopping/expense).
- [ ] Intent preview in UI before persistence.
- [ ] Reminder intent → ScheduleStore action.
- [ ] Shopping intent → shopping lifecycle action.
- [ ] Expense intent → confirmed expense lifecycle action.
- [ ] Idempotency / duplicate-write protection.

### P3. Voice-first Arabic
- [x] `ar-EG` speech input path.
- [ ] Improve dialect normalization and intent lexicon.
- [ ] Robust numeric/currency extraction.
- [ ] Confirmation for ambiguous commands.
- [ ] Failure recovery when speech service is unavailable.

### P4. Proactive Notifications
- [x] Notification settings surface.
- [x] Existing proactive appointment synchronization.
- [ ] Unified proactive insight coordinator across reminders, money, shopping and health.
- [ ] Quiet hours / frequency controls.
- [ ] User-configurable insight categories.

### P5. NUS Copilot
- [x] Existing AI hub entry point.
- [ ] NUS context layer for permitted appointments, reminders, money, shopping and goals.
- [ ] Server-side provider abstraction.
- [ ] Action proposals with explicit confirmation.
- [ ] Weekly life-status conversation.

### P6. Unified Work Model
- [ ] Common representation for tasks, appointments and obligations.
- [ ] Priority/state model.
- [ ] Single next-action engine.
- [ ] Recurrence integration.

## Phase 2 — Household

- [ ] Household members and roles.
- [ ] Shared shopping.
- [ ] Shared tasks.
- [ ] Bills and subscriptions.
- [ ] Household calendar.
- [ ] Home maintenance.
- [ ] Permission boundaries and shared/private data model.

## Phase 3 — Money

- [ ] Cashflow view.
- [ ] Installments.
- [ ] Debts and money owed/receivable.
- [ ] Recurring expenses.
- [ ] Financial goals execution.
- [ ] Spending anomaly detection.
- [ ] “هل أقدر أعمل ده؟” affordability analysis with scenarios.

## Phase 4 — Life

- [ ] Medication routines.
- [ ] Refill reminders.
- [ ] Health routines.
- [ ] Document reminders.
- [ ] Warranty tracking.
- [ ] Vehicle lifecycle.
- [ ] Recipes → Shopping → Budget loop.

## Localization packs

### Egypt
- Installments
- Associations
- Rent
- Utilities
- School expenses
- Lessons / childcare
- Transportation
- Family transfers
- Cash / wallet / card spending
- Personal debts

### Europe
- Subscriptions
- Rent
- Energy
- Insurance
- Tax-related reminders
- Household sharing
- Multi-currency
- Recurring payments
- Privacy/GDPR-first UX

## Privacy architecture

- Local-first by default.
- Data minimization.
- Encryption where sensitive data is stored.
- AI receives only the context required for the current task.
- No personal provider API key required from the end user.
- Provider credentials stay server-side and outside the mobile repository.

## Definition of done

A feature is complete only when:

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
APK VERIFIED (when Android-facing)
  =
DONE
```

## Current execution checkpoint

The active engineering work is stabilizing the NUS Today integration contract and validation pipeline before deeper Quick Add orchestration. Do not bypass this checkpoint by adding more disconnected UI.
