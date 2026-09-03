# NUS — Step 6 Phase 6.1
# Core Domain Expansion & Feature Architecture

## Scope

This phase establishes architecture only. It introduces no feature UI, persistence implementation, cloud synchronization, authentication behavior, AI provider SDK, or family/shared functionality.

## Layering rule

```text
UI / presentation
        ↓
application/domain contracts
        ↓
repository ports
        ↓
data sources / adapters
```

Feature code must depend inward. Domain models and repository ports must not import Flutter widgets, Supabase types, notification APIs, or an AI vendor SDK.

## Shared domain contract

`core/domain/domain_entity.dart` contains only stable identity. `core/domain/domain_repository.dart` provides a small optional CRUD-shaped repository port. A feature may extend or narrow the contract when business rules require operations that are not generic CRUD.

No concrete data-source implementation is created in this phase. This keeps local-first behavior possible and leaves storage choice explicit per feature.

## Feature boundaries

The following bounded domains are established because they are explicit NUS product requirements:

- `features/appointments/domain` — appointments, including future doctor visits as an appointment type. Clinical records and doctor-contact management remain deferred.
- `features/medications/domain` — medication identity and basic lifecycle state. Reminder timing stays separate so future medication scheduling can compose with the existing reminder subsystem.
- `features/shopping/domain` — shopping items and completion state. List/group behavior is deferred.
- `features/expenses/domain` — monetary expense records.
- `features/finance/domain` — budget records. No calculations or forecasting are implemented.
- `features/bills/domain` — bill records with due date and payment state.
- `features/notes/domain` — note identity and text content.

Each boundary is independent. Feature domains must not directly import other feature domains merely to share behavior.

## Model discipline

The models are intentionally minimal and immutable. Fields were limited to information required to name and identify the future concept plus obvious lifecycle/value data. Search, recurrence, attachments, contacts, sharing permissions, analytics, and other product details are deferred until requirements exist.

`SocialIdentity` and `Profile` remain separate accepted architecture and are not redefined here.

## AI architecture

`core/ai/ai_insight.dart` defines provider-neutral `AiInsight`, `AiContextItem`, and `AiInsightRequest`.

`core/ai/ai_insight_provider.dart` defines the provider boundary:

```text
Domain/application → AiInsightProvider → future provider adapter
```

No UI code receives or constructs an LLM SDK type. No Google, OpenAI, Gemini, or other AI dependency is introduced. A later provider adapter may transform domain context into a vendor-specific request without changing the domain model.

## Local-first rule

Repositories are ports, not storage implementations. A later local repository can satisfy a feature port without Supabase. A later remote adapter can be composed behind the same boundary where synchronization is explicitly introduced.

The existing local reminder subsystem remains outside this new architecture in this phase. `ScheduleStore`, `SharedPreferences`, `nos.schedule.v1`, `NotificationService`, and the accepted reminder lifecycle remain unchanged. Profile or AI availability is never a prerequisite for saving or scheduling a reminder.

## Supabase and authentication boundary

No Phase 6.1 feature imports Supabase. The accepted AuthRepository, Profile architecture, and SupabaseService remain unchanged. Cloud persistence and RLS are deferred to dedicated security/sync work.

## Deferred concepts

- doctor contact records and clinical metadata
- medication dose schedules and prescription details
- shopping lists and recurrence
- expense analytics and reporting
- budget calculations, forecasts, and economic planning engines
- bill providers/autopay metadata
- note folders, search, attachments, and collaboration
- family/shared ownership and permissions
- AI provider selection, credentials, quotas, prompt policies, and cloud inference

## Dependency policy

This phase adds no package dependency. Dart core types are sufficient. State management, networking, storage, AI SDKs, and new authentication SDKs are intentionally absent.

## Testing strategy

Architecture tests use fakes rather than live databases or providers. They verify shared domain identity, repository-port testability, and an AI boundary that returns a domain-level `AiInsight` without a provider SDK.
