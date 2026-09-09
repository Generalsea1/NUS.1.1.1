import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/today/presentation/nus_quick_add_page.dart';

void main() {
  testWidgets('quick add exposes fast time shortcuts', (tester) async {
    DateTime? savedAt;
    String? savedTitle;

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (title, dateTime) async {
            savedTitle = title;
            savedAt = dateTime;
          },
        ),
      ),
    );

    expect(find.text('بعد ساعة'), findsOneWidget);
    expect(find.text('بكرة 9 صباحًا'), findsOneWidget);
    expect(find.text('بكرة 6 مساءً'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'دفع الكهرباء');
    await tester.tap(find.text('بكرة 9 صباحًا'));
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pumpAndSettle();

    expect(savedTitle, 'دفع الكهرباء');
    expect(savedAt, isNotNull);
    expect(savedAt!.hour, 9);
  });

  testWidgets('quick add previews an expense and blocks reminder persistence', (tester) async {
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (_, __) async {
            saveCalls += 1;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'دفعت 350 جنيه مواصلات');
    await tester.pump();

    expect(find.text('NUS فهمها كـ مصروف'), findsOneWidget);
    expect(find.textContaining('350 EGP'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('quick-add-save')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pump();
    expect(saveCalls, 0);
  });
}
