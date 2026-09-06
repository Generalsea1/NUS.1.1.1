import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nus/main.dart';
import 'package:nus/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeReminderScheduler implements ReminderScheduler {
  int scheduledCount = 0;

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduledCount += 1;
  }

  @override
  Future<void> cancelReminder(String id) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('NUS renders the modern schedule dashboard', (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('NUS'), findsOneWidget);
    expect(find.text('What is on your agenda?'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
  });

  Future<void> openReminderSheet(WidgetTester tester) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New reminder'), findsOneWidget);
  }

  testWidgets('saving a valid reminder dismisses the sheet before scheduling',
      (tester) async {
    final scheduler = _FakeReminderScheduler();
    final store = ScheduleStore(notifications: scheduler);

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    await openReminderSheet(tester);
    await tester.enterText(find.byType(TextField), 'موعد اختبار');
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('New reminder'), findsNothing);
    expect(store.items, hasLength(1));
    expect(store.items.single.title, 'موعد اختبار');
    expect(scheduler.scheduledCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid reminder input stays rejected without closing the sheet',
      (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    await openReminderSheet(tester);
    await tester.tap(find.text('Save reminder'));
    await tester.pumpAndSettle();

    expect(find.text('New reminder'), findsOneWidget);
    expect(store.items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling reminder creation closes the sheet without saving',
      (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    await openReminderSheet(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('New reminder'), findsNothing);
    expect(store.items, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
