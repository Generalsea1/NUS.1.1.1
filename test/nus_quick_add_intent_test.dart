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

  test('defaults ordinary natural language to reminder', () {
    final result = NusQuickAddIntentClassifier.classify('كلم الدكتور بكرة');

    expect(result.kind, NusQuickAddKind.reminder);
    expect(result.confidence, greaterThan(0));
  });

  test('supports Arabic-Indic digits for money', () {
    final result = NusQuickAddIntentClassifier.classify('دفعت ٣٥٠ جنيه كهربا');

    expect(result.kind, NusQuickAddKind.expense);
    expect(result.amountMajorUnits, 350);
    expect(result.expenseCategoryCode, 'utilities');
  });
}
