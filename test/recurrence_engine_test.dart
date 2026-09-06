import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/recurrence/recurrence_engine.dart';
import 'package:nus/core/recurrence/recurrence_rule.dart';

void main() {
  const engine = RecurrenceEngine();

  group('RecurrenceRule', () {
    test('daily and weekly rules are valid', () {
      expect(const RecurrenceRule.daily().validate(), isEmpty);
      expect(const RecurrenceRule.weekly().validate(), isEmpty);
    });

    test('selected weekdays require valid ISO weekdays', () {
      expect(
        RecurrenceRule.selectedWeekdays(<int>{}).validate(),
        contains('weekdays_required'),
      );
      expect(
        RecurrenceRule.selectedWeekdays(<int>{0}).validate(),
        contains('invalid_weekday'),
      );
      expect(
        RecurrenceRule.selectedWeekdays(<int>{1, 3, 7}).validate(),
        isEmpty,
      );
    });
  });

  group('RecurrenceEngine', () {
    test('generates daily occurrences from the exact start time', () {
      final values = engine
          .occurrences(
            start: DateTime(2026, 9, 1, 9),
            rule: const RecurrenceRule.daily(),
            windowStart: DateTime(2026, 9, 1),
            windowEnd: DateTime(2026, 9, 5),
          )
          .toList();

      expect(values, <DateTime>[
        DateTime(2026, 9, 1, 9),
        DateTime(2026, 9, 2, 9),
        DateTime(2026, 9, 3, 9),
        DateTime(2026, 9, 4, 9),
      ]);
    });

    test('generates weekly occurrences seven days apart', () {
      final values = engine
          .occurrences(
            start: DateTime(2026, 9, 2, 14, 30),
            rule: const RecurrenceRule.weekly(),
            windowStart: DateTime(2026, 9, 1),
            windowEnd: DateTime(2026, 9, 30),
          )
          .toList();

      expect(values, <DateTime>[
        DateTime(2026, 9, 2, 14, 30),
        DateTime(2026, 9, 9, 14, 30),
        DateTime(2026, 9, 16, 14, 30),
        DateTime(2026, 9, 23, 14, 30),
      ]);
    });

    test('filters daily occurrences by selected weekdays', () {
      final values = engine
          .occurrences(
            start: DateTime(2026, 9, 1, 8),
            rule: RecurrenceRule.selectedWeekdays(<int>{1, 3, 5}),
            windowStart: DateTime(2026, 9, 1),
            windowEnd: DateTime(2026, 9, 8),
          )
          .toList();

      expect(values, <DateTime>[
        DateTime(2026, 9, 2, 8),
        DateTime(2026, 9, 4, 8),
        DateTime(2026, 9, 7, 8),
      ]);
    });

    test('can include past occurrences for cancellation reconciliation', () {
      final values = engine
          .occurrences(
            start: DateTime(2026, 8, 30, 8),
            rule: const RecurrenceRule.daily(),
            windowStart: DateTime(2026, 9, 1),
            windowEnd: DateTime(2026, 9, 3),
            includePastOccurrences: true,
          )
          .toList();

      expect(values, <DateTime>[
        DateTime(2026, 8, 30, 8),
        DateTime(2026, 8, 31, 8),
        DateTime(2026, 9, 1, 8),
        DateTime(2026, 9, 2, 8),
      ]);
    });

    test('does not emit an invalid rule', () {
      final values = engine
          .occurrences(
            start: DateTime(2026, 9, 1),
            rule: RecurrenceRule.selectedWeekdays(<int>{}),
            windowStart: DateTime(2026, 9, 1),
            windowEnd: DateTime(2026, 9, 10),
          )
          .toList();

      expect(values, isEmpty);
    });
  });
}
