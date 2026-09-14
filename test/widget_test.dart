import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/application/expense_lifecycle_service.dart';
import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/data/supabase_expense_repository.dart';
import 'package:nus/features/expenses/data/supabase_recurring_expense_repository.dart';
import 'package:nus/features/medications/application/medication_lifecycle_service.dart';
import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/medications/domain/medication_reminder_port.dart';
import 'package:nus/features/shopping/application/shopping_lifecycle_service.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';
import 'package:nus/main.dart';
import 'package:nus/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMedicationReminderPort implements MedicationReminderPort {
  int scheduledCount = 0;

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduledCount += 1;
  }

  @override
  Future<void> cancel(String id) async {}
}

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

Nus2App _buildApp({required ScheduleStore store}) {
  final expenseService = ExpenseLifecycleService(
    repository: LocalExpenseRepository(),
  );
  final medicationService = MedicationLifecycleService(
    repository: LocalMedicationRepository(),
    reminders: MedicationReminderCoordinator(_FakeMedicationReminderPort()),
  );
  final shoppingService = ShoppingLifecycleService(
    repository: LocalShoppingRepository(),
  );
  final expenseManagementService = ExpenseManagementService(
    expenseRepository: const SupabaseExpenseRepository(),
    recurringRepository: const SupabaseRecurringExpenseRepository(),
  );

  return Nus2App(
    store: store,
    medicationService: medicationService,
    shoppingService: shoppingService,
    expenseService: expenseService,
    expenseManagementService: expenseManagementService,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('NUS starts on the authenticated financial app boundary',
      (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(_buildApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('NUS'), findsOneWidget);
    expect(find.text('مدير الاقتصاد الذكي للمنزل'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
    expect(find.text('مركز الذكاء الاصطناعي'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured NUS remains safely at the account boundary',
      (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(_buildApp(store: store));
    await tester.pumpAndSettle();

    expect(
      find.text('أنشئ حسابك، ثم سنجهّز معك الملف المالي الحقيقي للبيت.'),
      findsOneWidget,
    );
    expect(find.text('Gemini'), findsNothing);
    expect(find.text('ضع مفتاح'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ScheduleStore reminder lifecycle remains wired after app migration',
      (tester) async {
    final scheduler = _FakeReminderScheduler();
    final store = ScheduleStore(notifications: scheduler);

    await store.add(
      'مراجعة الميزانية',
      DateTime.now().add(const Duration(hours: 1)),
    );

    expect(store.items, hasLength(1));
    expect(store.items.single.title, 'مراجعة الميزانية');
    expect(scheduler.scheduledCount, 1);
    expect(tester.takeException(), isNull);
  });
}
