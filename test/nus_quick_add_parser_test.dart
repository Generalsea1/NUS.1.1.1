import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/today/domain/nus_quick_add_parser.dart';

void main() {
  final now = DateTime(2026, 9, 9, 13, 30);

  test('parses Arabic day phrase without treating day number as hour', () {
    final result = NusQuickAddParser.parse('ادفع الكهرباء يوم 15', now: now);

    expect(result.title, 'ادفع الكهرباء');
    expect(result.dateTime, DateTime(2026, 9, 15, 9));
    expect(result.scheduleDetected, isTrue);
  });

  test('parses tomorrow with explicit evening time', () {
    final result = NusQuickAddParser.parse('كلم الدكتور بكرة الساعة 6 مساء', now: now);

    expect(result.title, 'كلم الدكتور');
    expect(result.dateTime, DateTime(2026, 9, 10, 18));
    expect(result.scheduleDetected, isTrue);
  });

  test('parses numeric date and keeps the real task title', () {
    final result = NusQuickAddParser.parse('اشتري دواء 15/9 الساعة 10', now: now);

    expect(result.title, 'اشتري دواء');
    expect(result.dateTime, DateTime(2026, 9, 15, 10));
    expect(result.scheduleDetected, isTrue);
  });

  test('parses relative Arabic hour and Arabic digits', () {
    final result = NusQuickAddParser.parse('راجع الفاتورة بعد ساعة', now: now);

    expect(result.title, 'راجع الفاتورة');
    expect(result.dateTime, DateTime(2026, 9, 9, 14, 30));
    expect(result.scheduleDetected, isTrue);
  });

  test('does not invent a schedule when text has no supported time phrase', () {
    final result = NusQuickAddParser.parse('شراء مستلزمات البيت', now: now);

    expect(result.title, 'شراء مستلزمات البيت');
    expect(result.dateTime, DateTime(2026, 9, 9, 14, 30));
    expect(result.scheduleDetected, isFalse);
  });
}
