import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/proactive_notifications.dart';

void main() {
  test('plans only enabled future signals and keeps the earliest three', () {
    final now = DateTime(2026, 9, 9, 8);
    final planner = NusProactiveNotificationPlanner();

    final result = planner.plan(
      now: now,
      signals: [
        NusProactiveSignal(id: 'late', title: 'Late', body: 'Late', scheduledAt: now.add(const Duration(hours: 4))),
        NusProactiveSignal(id: 'past', title: 'Past', body: 'Past', scheduledAt: now.subtract(const Duration(minutes: 1))),
        NusProactiveSignal(id: 'off', title: 'Off', body: 'Off', scheduledAt: now.add(const Duration(hours: 1)), enabled: false),
        NusProactiveSignal(id: 'one', title: 'One', body: 'One', scheduledAt: now.add(const Duration(minutes: 10))),
        NusProactiveSignal(id: 'two', title: 'Two', body: 'Two', scheduledAt: now.add(const Duration(minutes: 20))),
        NusProactiveSignal(id: 'three', title: 'Three', body: 'Three', scheduledAt: now.add(const Duration(minutes: 30))),
      ],
    );

    expect(result.map((item) => item.id), ['proactive:one', 'proactive:two', 'proactive:three']);
  });

  test('planner is pure and never rewrites supplied facts', () {
    final now = DateTime(2026, 9, 9, 8);
    const signal = NusProactiveSignal(
      id: 'appointment',
      title: 'موعد الطبيب',
      body: 'عندك موعد الطبيب',
      scheduledAt: DateTime(2026, 9, 9, 10),
    );

    final result = NusProactiveNotificationPlanner().plan(
      now: now,
      signals: [signal],
    );

    expect(result.single.title, signal.title);
    expect(result.single.body, signal.body);
    expect(result.single.scheduledAt, signal.scheduledAt);
  });

  test('planner respects an explicit zero notification budget', () {
    final now = DateTime(2026, 9, 9, 8);
    final planner = NusProactiveNotificationPlanner(maxItems: 0);

    final result = planner.plan(
      now: now,
      signals: [
        NusProactiveSignal(
          id: 'one',
          title: 'One',
          body: 'One',
          scheduledAt: now.add(const Duration(minutes: 10)),
        ),
      ],
    );

    expect(result, isEmpty);
  });
}
