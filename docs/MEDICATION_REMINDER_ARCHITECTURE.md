# Medication Reminder Integration

Phase 6.3.3 adds Medication-owned reminder orchestration without changing the existing reminder infrastructure.

## Boundary

`MedicationReminderCoordinator`
→ `MedicationReminderPort`
→ `MedicationReminderAdapter`
→ existing `ReminderScheduler`
→ existing `NotificationService`

The Medication domain remains independent from notification plugins and Android APIs.

## Occurrences

Only `daily` and `selectedWeekdays` are supported. Occurrences are generated from the stored date-only medication range and `minutesSinceMidnight`. No timezone or calendar recurrence engine is introduced.

## Scheduling horizon

The coordinator schedules only future occurrences up to a 30-day rolling horizon. Optional `endDate` is inclusive. Inactive medications and schedules using `MedicationReminder.none` are not scheduled.

## Reminder IDs

IDs are derived from a canonical, medication-specific namespace:

`medication:<medicationId>:schedule:<scheduleId>:occurrence:<YYYY-MM-DD>:<HH-MM>`

The canonical key is converted to a stable positive numeric identifier using the same FNV-style approach already used by Appointment reminders. Medication names, dosage, notes, and other content are not part of the ID.

## Synchronization and cancellation

`sync()` cancels the managed reminder set for the supplied (or previous) Medication definition before rebuilding the current active reminder set. This makes edits, reminder disabling, schedule replacement, inactive transitions, and repeated synchronization deterministic without modifying Appointment behavior.

## Privacy and scope

No medication data is logged or sent to a cloud service. This phase contains no UI, Supabase integration, Auth/Profile changes, AI, dose history, adherence tracking, or notification infrastructure redesign.
