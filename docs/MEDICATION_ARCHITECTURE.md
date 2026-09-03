# NUS — Medication Architecture (Phase 6.3.2)

Phase 6.3.2 establishes the Medication domain model and local persistence foundation only.

## Aggregate boundary

`Medication` is the single aggregate root and implements `DomainEntity`. It owns immutable-style value objects for dosage and embedded medication schedules. `MedicationSchedule` is not a `DomainEntity` and has no repository of its own.

## Dosage

`Dosage` stores the organizer-level values `amount`, `unit`, and optional `customUnit`. Amount remains a string so user-entered representations are preserved. No calculation, numeric conversion, unit conversion, clinical validation, or safety analysis is performed.

Built-in units are `tablet`, `capsule`, `ml`, `drop`, `puff`, `injection`, and `custom`.

## Schedule and frequency

A schedule has a stable caller-owned `id`, `minutesSinceMidnight` from 0 through 1439, a frequency, selected ISO-style weekday numbers where applicable (1=Monday through 7=Sunday), and a domain-only reminder preference.

The initial frequency model is limited to `daily` and `selected_weekdays`. No interval or complex recurrence scheduling exists in this phase.

Schedule identity is an opaque stable string supplied by the application layer. It is preserved when editing unless the schedule is intentionally replaced. It is never derived from list index, `hashCode`, or object identity.

Reminder values are local Medication domain data only: none, at time, or the supported relative offsets. This phase does not schedule or cancel notifications.

## Date semantics

`startDate` is required and `endDate` is optional and inclusive. Dates are normalized to local date-only values (`year`, `month`, `day`). The domain has no timezone or notification scheduling logic.

## Persistence boundary

`MedicationRepository` extends the existing `DomainRepository<Medication>` CRUD contract. `LocalMedicationRepository` implements it with `SharedPreferences` using the dedicated key `nus.medications.v1`.

Malformed individual stored records are ignored so one bad record does not prevent valid medications from loading. A malformed entire JSON payload yields an empty collection rather than crashing the store. Duplicate medication IDs are de-duplicated on read (first valid record wins) and replaced by ID on save.

Repository ordering is deterministic: active medications first, then `startDate`, then stable `id`. Medication IDs are application-owned stable identifiers independent of medication name; this phase does not add an ID-generation dependency.

## JSON contract

Enum values use stable strings rather than enum indexes. Dates use `YYYY-MM-DD`. Schedule weekday values use integers 1 through 7. Serialization is deterministic, including stable schedule ordering in the emitted JSON.

## Defensive mutability

`Medication` and its schedule collection are defensively copied at construction. `MedicationSchedule.selectedWeekdays` is also defensively copied and exposed as an unmodifiable list.

## Explicit exclusions

This phase contains no UI, no reminder coordinator or adapter, no notification scheduling/cancellation, no changes to `NotificationService` or `ScheduleStore`, no Appointment/Auth/Profile/Supabase/AI work, and no clinical functionality.

Actual medication reminder integration is deferred to the next approved phase.
