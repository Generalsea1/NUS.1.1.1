import 'package:flutter_test/flutter_test.dart';
import 'package:nos/main.dart';

void main() {
  testWidgets('NOS renders the schedule home screen', (tester) async {
    final store = ScheduleStore();

    await tester.pumpWidget(NosApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('إيه اللي وراك؟'), findsOneWidget);
    expect(find.text('إضافة تذكير'), findsOneWidget);
    expect(find.text('النهارده'), findsOneWidget);
  });
}
