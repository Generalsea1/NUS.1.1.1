abstract interface class MedicationReminderPort {
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  });

  Future<void> cancel(String id);
}
