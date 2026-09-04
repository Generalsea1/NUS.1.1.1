# NUS MASTER PRODUCT & ARCHITECTURE CONSTITUTION v1.0

Status: AUTHORITATIVE
Baseline: `c949e1e49d0790e4722da66552111f19cc208099`
Purpose: single product and architectural source of truth for future NUS development.

## 1. Product vision

NUS is a Personal Life Operating System: one coherent local-first application for organizing the user's day, money, health-related organizer data, shopping, notes, home responsibilities, goals, and future intelligence.

NUS must remain useful without AI, cloud connectivity, or an account. Cloud, AI, Family/Shared, and automation capabilities are additive capabilities, never hidden prerequisites for core personal data capture.

Arabic and English are first-class product modes. RTL/LTR behavior is a product requirement, not a cosmetic layer.

## 2. Constitutional principles

1. Preserve user data and working behavior before adding capability.
2. Inspect → plan → execute → test → verify → evidence → accept/reject → close.
3. Prefer the smallest change that satisfies the requirement.
4. Domain rules live in domain/application layers, not widgets or persistence adapters.
5. Feature data access crosses repository ports; UI does not write storage directly.
6. Local-first is the default operating mode.
7. Cross-domain coupling is explicit and minimal.
8. IDs are stable, opaque, application-owned identities; names, indexes and hashes are not identities.
9. Existing reminder infrastructure is protected until a separately approved migration proves equivalence.
10. Secrets never enter source control; `service_role` and database passwords never enter the client application.
11. AI is accessed only through a provider-neutral gateway.
12. No large rewrite, dependency expansion, or architecture migration is justified without a concrete requirement and verification plan.

## 3. Current domain map

### Core platform domains

- Core Domain: `DomainEntity`, `DomainRepository`.
- Identity: `AppIdentity`.
- Authentication: `AuthRepository`, `AuthState/AuthSession/AuthUser`, `SupabaseAuthRepository`.
- Profile: `Profile`, `ProfileRepository`, Supabase mapping boundary.
- AI: `AiInsight`, `AiContextItem`, `AiInsightRequest`, `AiInsightProvider`.
- Supabase: single `SupabaseService` initialization boundary.
- Notifications: `NotificationService` implementing `ReminderScheduler`.
- Legacy local reminders: `ScheduleStore` with `nos.schedule.v1`.

### Product domains

- Schedule / Reminders: current personal day-planning foundation.
- Appointments: local-first appointments with recurrence and reminder adapters.
- Medications: local-first medication aggregate with a medication-owned reminder coordinator.
- Shopping: local-first `ShoppingList` aggregate and child items.
- Expenses: local-first money/expense aggregate and lifecycle service.
- Finance: budget domain foundation only.
- Bills: bill domain foundation only.
- Notes: note domain foundation only.

Future product domains are defined below but are not considered implemented merely because their names exist in the roadmap.

## 4. Feature map and present maturity

| Domain | Current repository state | Target architectural direction |
|---|---|---|
| Schedule/Reminders | Implemented legacy local store + notification service | Protected infrastructure; future migration only by explicit plan |
| Appointments | Presentation + application reminder coordinator + data/domain | Maintain bounded feature and compose with central recurrence/event contracts later |
| Medications | Presentation + lifecycle + local repository + reminder coordinator/adapter | Maintain bounded feature; migrate recurrence semantics only with proof |
| Shopping | Presentation + lifecycle + local repository + aggregate domain | Maintain aggregate boundary; later financial links via application queries |
| Expenses | Presentation + lifecycle + local repository + money/date domain | Complete Phase 6.5, then build financial read/query capabilities |
| Finance | Domain-only budget model | Phase 7 implementation |
| Bills | Domain-only bill model | Future Phase 7/financial implementation |
| Notes | Domain-only note model | Phase 9 implementation |
| AI | Provider-neutral core contracts only | Phase 11 gateway/runtime implementation |
| Auth/Profile/Supabase | Foundational boundaries, no full product account flow | Phase 13/15 controlled expansion |
| Family/Shared | Not implemented | Phase 14 |
| Home Manager | Not implemented | Phase 10 |

## 5. Layering rule

The canonical feature dependency direction is:

```text
Presentation/UI
      ↓
Application/use-case services
      ↓
Domain models + feature contracts
      ↓
Repository/event ports
      ↓
Local/remote data adapters
      ↓
Storage/provider infrastructure
```

Domain code must not import Flutter UI, Supabase SDK types, notification plugin APIs, Android APIs, or AI vendor SDKs.

Presentation code may depend on application services and domain contracts, but must not directly access `SharedPreferences`, Supabase clients, notification plugins, SQL, or provider SDKs.

## 6. Repository boundaries

`DomainRepository<T>` is the shared CRUD-shaped port. Feature repositories may narrow or extend it when business semantics require it.

Repositories own persistence translation, serialization, recovery behavior, and storage-key ownership. Application services own lifecycle orchestration and use-case rules. UI owns presentation state only.

No feature may reach into another feature's concrete repository. A cross-domain use case must consume an explicit application/query/event boundary.

## 7. Storage boundaries

Every persistent aggregate must have an explicit versioned storage namespace. Current accepted local namespaces include:

- `nos.schedule.v1` — legacy ScheduleStore; protected.
- `nus.appointments.v1` — appointments.
- `nus.medications.v1` — medications.
- `nus.shopping.v1` — shopping.
- `nus.expenses.v1` — expenses.

Storage keys are contracts. They must not be silently renamed, reused, or shared between unrelated aggregates.

Malformed record handling must be deterministic and fail-safe. A bad individual record must not destroy valid neighboring records. Root-payload corruption must not be silently overwritten when that would risk data loss.

## 8. ID strategy

IDs must be:

- stable across edits and reloads;
- independent from displayed names, positions, array indexes and content;
- owned by the application/domain boundary;
- safe to use for reminders, navigation and future synchronization.

Changing a display name never changes identity. Derived notification IDs may be deterministic transformations of canonical IDs, but user-entered content must not be encoded into identifiers.

The existing schedule identity uses timestamp-derived string IDs. Feature domains already use opaque stable IDs. Any future global identity policy must be introduced through migration, not retroactively assumed.

## 9. Cross-domain references

Direct domain-to-domain object imports are prohibited by default.

Examples:

- Shopping may later reference an expense or purchase relation through an application/query contract, not by importing `Expense` into the Shopping domain.
- Finance may consume Expense information through read/query interfaces, never by making Expenses depend on Finance.
- Appointments and Medications may both consume reminder infrastructure through ports/adapters, not through each other's domain models.

Cross-domain references must specify ownership, lifecycle, deletion behavior, privacy classification, and migration behavior before implementation.

## 10. Cross-domain events

NUS should evolve toward explicit application-level domain events for facts such as `ExpenseRecorded`, `AppointmentChanged`, `MedicationReminderChanged`, `ShoppingItemCompleted`, and `TaskCompleted`.

No general event bus is declared implemented in v1.0. Until one is explicitly introduced and tested, features must use direct ports/coordinators or local callbacks where already established.

Future events must be:

- immutable;
- versionable;
- small and identity-based;
- free of provider/UI objects;
- privacy-classified;
- safe to replay or ignore when appropriate.

## 11. Central Recurrence Engine

NUS will have one canonical future Recurrence Engine for recurrence calculation across appointments, reminders, medication schedules, tasks, bills and other recurring domains.

Current reality is intentionally preserved: Appointment and Medication reminder coordinators contain their current supported recurrence rules. These implementations are protected until a dedicated migration demonstrates identical occurrence generation, cancellation semantics, IDs, horizons, and edge-case behavior.

The Recurrence Engine must be domain-neutral. It computes occurrences from explicit recurrence definitions; it does not own notification delivery.

## 12. Notification architecture

The protected current path is:

```text
Feature
  ↓
Feature reminder coordinator / adapter
  ↓
ReminderScheduler port
  ↓
NotificationService
  ↓
flutter_local_notifications + timezone
```

`NotificationService` owns local notification scheduling concerns. It initializes timezone support, requests notification/exact-alarm permissions where applicable, schedules/cancels notifications, and provides pending-notification inspection.

`ScheduleStore` owns legacy reminder persistence and remains separately protected. No Phase 6 feature may silently replace, rename, or migrate `nos.schedule.v1`.

Future notification unification must preserve notification IDs, cancellation, restart/reschedule behavior, permission semantics, and local-first operation.

## 13. Reminder architecture

Reminder creation remains a domain/application responsibility. Delivery is an infrastructure concern.

A feature that needs reminders should expose a feature-owned coordinator/adapter to the shared `ReminderScheduler` boundary. Features must not import `flutter_local_notifications` directly.

Reminder scheduling must be deterministic and idempotent where repeated synchronization is expected. Reminder IDs must be stable and content-minimal.

## 14. Security boundary

The Flutter application may contain only public/publishable client configuration required by a provider SDK.

The following are forbidden in client code, source control, test fixtures, or build artifacts:

- Supabase `service_role` keys;
- database passwords;
- OAuth client secrets;
- private signing secrets;
- unrestricted server credentials.

All authenticated data access must pass through an application repository boundary and the approved Supabase client boundary. Database authorization is ultimately enforced by server-side RLS/grants, not by client trust.

## 15. Authentication and profile boundary

The canonical current architecture is:

```text
UI/application
    ↓
AuthRepository
    ↓
SupabaseAuthRepository
    ↓
SupabaseService
    ↓
Supabase client
```

The authenticated identity is the canonical profile identity. Profile code must not invent an independent authenticated-user identity source.

When Supabase is unconfigured, local-first functionality must remain usable. No fake identity is created to make the app appear authenticated.

## 16. AI Gateway boundary

The current AI contract is provider-neutral:

```text
Application
   ↓
AiInsightProvider
   ↓
approved provider adapter or future local model
```

UI and domains must never construct OpenAI/Gemini/other vendor SDK requests directly.

AI is optional. Core user data operations must remain functional without AI.

## 17. AI context and data permissions

AI access is deny-by-default at the data-classification level.

A future AI gateway must accept only explicit context selected by an application-level permission policy. Context must be:

- purpose-bound;
- minimal;
- read-only unless a separate command permission is granted;
- scoped to the current authenticated/local user;
- auditable at the application boundary;
- stripped of secrets and unnecessary identifiers.

Sensitive data such as health/medication details, financial information, personal notes, contacts, authentication data and Personal Vault content must not be included in AI context unless an explicit product permission exists.

The AI provider must never gain unrestricted repository access.

## 18. Personal Vault isolation

Personal Vault is a future high-privacy zone for documents, secrets, sensitive notes, credentials, private records, or other deliberately isolated content.

The Vault must have:

- a dedicated domain/storage boundary;
- explicit encryption/key-management design;
- no implicit AI access;
- no Family/Shared access by default;
- no notification payload leakage;
- explicit export/recovery policy.

No Vault implementation is declared in v1.0.

## 19. Future Supabase boundary

Supabase is the future authenticated cloud boundary, not the default local storage engine.

The current project includes a single `SupabaseService` initialization foundation and publishable-key configuration via runtime/build-time defines. When configuration is absent or invalid, the app remains local-first.

No new Supabase tables, migrations, sync jobs, Storage buckets, Realtime subscriptions, or RLS policies are introduced merely by this constitution.

## 20. Future Sync Engine

Sync will be a separate application/data concern. A future Sync Engine must define:

- canonical identity mapping;
- local operation/change metadata;
- conflict policy;
- ordering and retry behavior;
- tombstones/deletions;
- schema/version migration;
- privacy boundaries;
- offline queue behavior.

Repositories must remain replaceable so local-first features do not become cloud-dependent before Sync is formally adopted.

## 21. Future Family / Shared architecture

Family/Shared is a separate ownership and authorization model, not a simple boolean flag on personal records.

A future shared record must distinguish:

- owner;
- participants/members;
- roles/permissions;
- visibility;
- mutation rights;
- audit expectations;
- revocation behavior.

Personal data is private by default. No family/sharing behavior is implemented by this constitution.

## 22. Android requirements

The repository currently contains an Android scaffold and the CI workflow can generate/build Android artifacts. Android work is outside this constitution task.

Phase 16 will formalize production Android requirements including application identity, notification permissions, exact-alarm policy where required, backup/export policy, release signing, deep links, foreground/background behavior, and production build verification.

No new `android/` generation or rewrite is performed here.

## 23. Testing strategy

Every feature must have a layered test portfolio:

1. Domain tests: invariants, value objects, IDs, serialization semantics.
2. Application tests: lifecycle orchestration, repository interaction, idempotency, failure paths.
3. Data tests: persistence round trips, malformed input handling, ordering, version boundaries.
4. UI tests: user-visible states and interaction against the actual interactive controls.
5. Architecture tests: forbidden dependencies and boundary enforcement.
6. CI verification: analyze, targeted feature tests, full suite, build artifact verification where applicable.

Tests must use fakes for external services unless a phase explicitly authorizes an integration environment.

## 24. Definition of Done

A phase/item is DONE only when:

- implementation matches the approved scope;
- no forbidden architecture dependency was introduced;
- relevant tests pass;
- `flutter analyze` passes;
- the phase CI gate passes;
- the resulting commit/branch identity is verified;
- no protected infrastructure was altered without explicit approval;
- evidence is recorded.

A failing test can be marked BLOCKED only when the failure is accurately isolated and unrelated work can continue.

## 25. Migration and change rules

- Never perform multi-domain migrations as an incidental part of a feature task.
- Never rewrite a working subsystem to make a new feature easier.
- Storage schema changes require versioning and a rollback/recovery plan.
- Rename/move operations require a compatibility plan and evidence.
- Dependency additions require a product/technical justification.
- Architecture migrations require before/after tests and verification of behavior equivalence.
- Existing protected keys, IDs, notifications and reminder behavior require explicit regression gates.

## 26. Protected infrastructure

The following are protected unless a task explicitly authorizes a dedicated migration:

- `ScheduleStore` and `nos.schedule.v1`;
- `NotificationService` and the `ReminderScheduler` boundary;
- existing notification IDs and rescheduling/cancellation semantics;
- `AppIdentity` canonical NUS identity values;
- AuthRepository/SupabaseAuthRepository boundary;
- Profile identity contract;
- `SupabaseService` local-first initialization behavior;
- feature repository/storage boundaries already established;
- Money/Expense exact integer minor-unit representation;
- stable entity IDs;
- Arabic RTL / English LTR support;
- test architecture and CI verification gates.

## 27. Current architectural inconsistencies to resolve deliberately

1. Legacy ScheduleStore remains in `lib/main.dart` while newer domains use feature boundaries. This is an acknowledged protected legacy boundary, not an excuse for an opportunistic rewrite.
2. Recurrence logic is distributed between appointment and medication coordinators. The central Recurrence Engine is a future convergence target, but migration is deferred until equivalence can be proven.
3. Bills, Finance and Notes have domain foundations without complete application/data/presentation layers. They are scaffolding, not completed product features.
4. Supabase foundation and auth/profile boundaries exist, but the repository does not yet contain a production sync/RLS deployment program. Cloud adoption therefore remains future work.
5. The current Expense UI test suite has a known hit-test failure at c949. Its root cause remains NOT PROVEN and is explicitly isolated from unrelated architecture work.

## 28. Phase operating rule

Only one implementation phase is opened as the active product change at a time. Blocking an individual item does not block unrelated architecture/documentation work unless the blocked item is a true dependency.

The current active product phase remains 6.5 Expenses. Phase 7 must not start as an implementation stream merely because the architecture constitution exists.

## 29. Authority and conflict resolution

This constitution is the master architecture/product authority for NUS v1.0.

Existing phase architecture documents remain valid as historical and domain-specific records. When an older document conflicts with this constitution, this constitution controls future work; the older document must not be silently rewritten to hide historical decisions.

Product requirements may supersede a constitutional rule only through an explicit constitution revision with a version increment and migration note.

## 30. Revision policy

Current revision: v1.0.

Any material architectural change requires a new revision (v1.1, v1.2, etc.). Amendments must state:

- reason;
- affected domains;
- migration impact;
- compatibility impact;
- test/evidence requirement;
- protected infrastructure impact.
