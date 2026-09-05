/// Domain-neutral recurrence definitions used only for occurrence calculation.
///
/// This model deliberately owns no notification, persistence, or feature state.
enum RecurrenceFrequency {
  daily,
  weekly,
  selectedWeekdays,
}

class RecurrenceRule {
  const RecurrenceRule._({
    required this.frequency,
    this.selectedWeekdays = const <int>{},
  });

  const RecurrenceRule.daily() : this._(frequency: RecurrenceFrequency.daily);

  const RecurrenceRule.weekly() : this._(frequency: RecurrenceFrequency.weekly);

  factory RecurrenceRule.selectedWeekdays(Set<int> weekdays) => RecurrenceRule._(
        frequency: RecurrenceFrequency.selectedWeekdays,
        selectedWeekdays: Set.unmodifiable(weekdays),
      );

  final RecurrenceFrequency frequency;
  final Set<int> selectedWeekdays;

  bool get isDaily => frequency == RecurrenceFrequency.daily;
  bool get isWeekly => frequency == RecurrenceFrequency.weekly;
  bool get isSelectedWeekdays =>
      frequency == RecurrenceFrequency.selectedWeekdays;

  List<String> validate() {
    if (!isSelectedWeekdays) return const <String>[];
    if (selectedWeekdays.isEmpty) return const <String>['weekdays_required'];
    if (selectedWeekdays.any((day) => day < DateTime.monday || day > DateTime.sunday)) {
      return const <String>['invalid_weekday'];
    }
    return const <String>[];
  }
}
