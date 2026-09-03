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

  testWidgets('NUS renders the schedule home screen', (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('إيه اللي وراك؟'), findsOneWidget);
    expect(find.text('إضافة تذكير'), findsOneWidget);
    expect(find.text('النهارده'), findsOneWidget);
  });

  testWidgets('saving a valid reminder dismisses the sheet before scheduling',
      (tester) async {
    final scheduler = _FakeReminderScheduler();
    final store = ScheduleStore(notifications: scheduler);

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة تذكير'));
    await tester.pumpAndSettle();
    expect(find.text('تذكير جديد'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'موعد اختبار');
    await tester.tap(find.text('احفظ التذكير'));
    await tester.pumpAndSettle();

    expect(find.text('تذكير جديد'), findsNothing);
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

    await tester.tap(find.text('إضافة تذكير'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احفظ التذكير'));
    await tester.pumpAndSettle();

    expect(find.text('تذكير جديد'), findsOneWidget);
    expect(store.items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling reminder creation closes the sheet without saving',
      (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة تذكير'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('تذكير جديد'), findsNothing);
    expect(store.items, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
