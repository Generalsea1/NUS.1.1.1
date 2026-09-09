import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/today/domain/nus_quick_add_intent.dart';

void main() {
  test('classifies a paid amount as an expense', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت 350 جنيه مواصلات');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 350);
    expect(result.currencyCode, 'EGP');
    expect(result.expenseCategoryCode, 'transportation');
    expect(result.confidence, greaterThanOrEqualTo(90));
  });

  test('classifies shopping language without a payment signal as shopping', () {
    final result = NusQuickAddIntentClassifier.classify('هات لبن وبيض وقائمة المشتريات');

    expect(result.kind, NusQuickAddKind.shopping);
    expect(result.amountMajorUnits, isNull);
  });

  test('classifies an explicit appointment as an appointment', () {
    final result = NusQuickAddIntentClassifier.classify('كلم الدكتور بكرة الساعة 10');

    expect(result.kind, NusQuickAddKind.appointment);
    expect(result.confidence, greaterThanOrEqualTo(90));
  });

  test('keeps a paid doctor visit as an expense instead of an appointment', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت 500 للدكتور');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 500);
    expect(result.expenseCategoryCode, 'healthcare');
  });

  test('defaults ordinary natural language to reminder', () {
    final result = NusQuickAddIntentClassifier.classify('خلص تقرير الشغل بكرة');

    expect(result.kind, NusQuickAddKind.reminder);
    expect(result.confidence, greaterThan(0));
  });

  test('supports Arabic-Indic digits for money', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت ٣٥٠ جنيه كهربا');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 350);
    expect(result.expenseCategoryCode, 'utilities');
  });

  test('normalizes Arabic diacritics and Egyptian dialect spelling', () {
    final result = NusQuickAddIntentClassifier.classify('دَفَعْتُ ٤٢٠ جُنَيْه أُوبَر');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 420);
    expect(result.currencyCode, 'EGP');
    expect(result.expenseCategoryCode, 'transportation');
  });

  test('detects explicit foreign currencies', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت 50 دولار مطعم');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 50);
    expect(result.currencyCode, 'USD');
    expect(result.expenseCategoryCode, 'food');
  });

  test('understands Egyptian shopping phrasing', () {
    final result = NusQuickAddIntentClassifier.classify('عايز اجيب منظف للبيت');

    expect(result.kind, NusQuickAddKind.shopping);
    expect(result.confidence, greaterThanOrEqualTo(90));
  });

  test('does not treat a payment phrase without an amount as an expense', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت الكهرباء');

    expect(result.kind, NusQuickAddKind.reminder);
    expect(result.amountMajorUnits, isNull);
  });
}
