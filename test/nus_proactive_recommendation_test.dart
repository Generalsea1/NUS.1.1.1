import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/today/domain/nus_proactive_recommendation.dart';

void main() {
  test('financial pressure has highest priority', () {
    final recommendations = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 4,
      todayAppointmentCount: 2,
      pendingShoppingItemCount: 5,
      financialPressure: true,
      nextAppointmentAt: DateTime(2026, 9, 9, 11),
      nextAppointmentTitle: 'دكتور',
    );

    expect(recommendations.first.id, 'review-finances');
    expect(recommendations.first.priority, NusRecommendationPriority.critical);
    expect(recommendations.length, 3);
  });

  test('heavy day produces organization recommendation', () {
    final recommendations = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 2,
      todayAppointmentCount: 1,
      pendingShoppingItemCount: 0,
      financialPressure: false,
    );

    expect(recommendations.map((item) => item.action), contains(NusRecommendationAction.organizeDay));
  });

  test('future appointment produces a preparation recommendation', () {
    final recommendations = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 0,
      todayAppointmentCount: 1,
      pendingShoppingItemCount: 0,
      financialPressure: false,
      nextAppointmentAt: DateTime(2026, 9, 9, 11, 30),
      nextAppointmentTitle: 'موعد البنك',
    );

    expect(recommendations, hasLength(1));
    expect(recommendations.first.id, 'prepare-next-appointment');
    expect(recommendations.first.message, contains('موعد البنك'));
    expect(recommendations.first.message, contains('11:30'));
  });

  test('shopping recommendation is omitted when nothing is pending', () {
    final recommendations = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 0,
      todayAppointmentCount: 0,
      pendingShoppingItemCount: 0,
      financialPressure: false,
    );

    expect(recommendations, isEmpty);
  });

  test('identical facts produce identical recommendation order', () {
    final args = <String, Object?>{};
    final first = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 3,
      todayAppointmentCount: 1,
      pendingShoppingItemCount: 2,
      financialPressure: true,
      nextAppointmentAt: DateTime(2026, 9, 9, 11),
      nextAppointmentTitle: 'موعد',
    );
    final second = NusProactiveRecommendationEngine.build(
      now: DateTime(2026, 9, 9, 8),
      pendingReminderCount: 3,
      todayAppointmentCount: 1,
      pendingShoppingItemCount: 2,
      financialPressure: true,
      nextAppointmentAt: DateTime(2026, 9, 9, 11),
      nextAppointmentTitle: 'موعد',
    );

    expect(first.map((item) => item.id).toList(), second.map((item) => item.id).toList());
    expect(args, isEmpty);
  });
}
