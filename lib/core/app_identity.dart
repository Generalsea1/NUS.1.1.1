/// Canonical product identity shared by application infrastructure.
///
/// Keep these values stable so UI, notifications, analytics, deep links,
/// and future backend adapters do not create independent product names.
abstract final class AppIdentity {
  static const String name = 'NUS';
  static const String packageName = 'nus';
  static const String scheduleChannelId = 'nus_schedule';
  static const String scheduleChannelName = 'NUS reminders';
  static const String scheduleChannelDescription =
      'Notifications for scheduled NUS reminders.';
  static const String reminderTitle = 'NUS Reminder';
}
