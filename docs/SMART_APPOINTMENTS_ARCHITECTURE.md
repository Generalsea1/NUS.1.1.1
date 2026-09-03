# NUS — Phase 6.2 Smart Appointments

## Scope

Phase 6.2 adds a local-first appointment-management feature without changing the accepted reminder, authentication, profile, or Supabase architectures.

## Boundary

```text
Presentation/UI
    ↓
Appointment Domain
    ↓
AppointmentRepository
    ↓
LocalAppointmentRepository
    ↓
SharedPreferences
```

The presentation layer never writes appointment persistence directly. `LocalAppointmentRepository` owns JSON serialization and the `nus.appointments.v1` local store.

## Appointment model

`Appointment` remains the single cohesive domain object for this phase. It contains title, type, start/end time, location, notes, contact information, recurrence, reminder configuration, status, and the limited doctor fields required for appointment handling.

Doctor appointments do not create medical records, diagnoses, clinical histories, prescriptions, recommendations, ratings, or other clinical data.

## Recurrence

Only `none`, `daily`, and `weekly` recurrence are supported. The reminder coordinator schedules a bounded set of future occurrences (12) through the existing reminder scheduler. No second notification architecture is introduced.

## Reminder boundary

```text
AppointmentReminderCoordinator
    ↓
AppointmentReminderPort
    ↓
ReminderSchedulerAppointmentAdapter
    ↓
existing ReminderScheduler / NotificationService
```

Appointment code does not modify `ScheduleStore` or the existing reminder persistence key. Notification identifiers are deterministic numeric IDs so scheduling and cancellation remain stable across app restarts with the existing notification service.

## Phone/contact boundary

A valid stored phone number creates an explicit `tel:` action from appointment details. The user must tap the call action. NUS does not auto-call and requests no call permission. When no suitable phone handler exists, the UI reports that the phone app is unavailable.

## Local-first rule

No Supabase table, migration, RLS policy, authentication change, or cloud synchronization is introduced in Phase 6.2. The appointment repository can therefore be replaced by another data source later without changing appointment UI/domain contracts.

## Validation

The domain validator checks required title/id, future time for upcoming appointments, end-after-start, valid recurrence/status combination, safe phone syntax, required doctor name, and follow-up after the doctor appointment.

## Out of scope

Medication, shopping, expenses, budgets, bills, notes, AI providers, cloud sync, Family Mode, and any redesign of the existing reminder system remain outside Phase 6.2.
