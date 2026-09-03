import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nos/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ScheduleItem round-trips through JSON without losing data', () {
    final item = ScheduleItem(
      id: '123',
      title: 'Call clinic',
      dateTime: DateTime(2026, 9, 3, 18, 30),
      completed: true,
    );

    final encoded = jsonEncode(item.toJson());
    final decoded = ScheduleItem.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(decoded.id, item.id);
    expect(decoded.title, item.title);
    expect(decoded.dateTime, item.dateTime);
    expect(decoded.completed, isTrue);
  });

  test('ScheduleStore persists valid reminders and sorts by date', () async {
    final store = ScheduleStore();
    final later = DateTime.now().add(const Duration(hours: 3));
    final sooner = DateTime.now().add(const Duration(hours: 1));

    await store.add('Later', later);
    await store.add('Sooner', sooner);

    expect(store.items.map((item) => item.title).toList(), ['Sooner', 'Later']);

    final secondStore = ScheduleStore();
    await secondStore.load();

    expect(
      secondStore.items.map((item) => item.title).toList(),
      ['Sooner', 'Later'],
    );
  });

  test('ScheduleStore rejects empty and past reminders', () async {
    final store = ScheduleStore();

    await store.add('   ', DateTime.now().add(const Duration(hours: 1)));
    await store.add('Past', DateTime.now().subtract(const Duration(minutes: 1)));

    expect(store.items, isEmpty);
  });

  test('toggle persists completion state and remove deletes the reminder', () async {
    final store = ScheduleStore();
    final itemTime = DateTime.now().add(const Duration(hours: 2));
    await store.add('Review contract', itemTime);
    final item = store.items.single;

    await store.toggle(item);
    expect(store.items.single.completed, isTrue);

    final restored = ScheduleStore();
    await restored.load();
    expect(restored.items.single.completed, isTrue);

    await restored.remove(restored.items.single);
    expect(restored.items, isEmpty);
  });
}
