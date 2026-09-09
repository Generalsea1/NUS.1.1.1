import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/today/domain/nus_shopping_text_parser.dart';

void main() {
  test('splits Egyptian shopping conjunctions with attached و', () {
    expect(
      NusShoppingTextParser.parse('هات لبن وبيض وعيش'),
      <String>['لبن', 'بيض', 'عيش'],
    );
  });

  test('supports Arabic comma, Latin comma, and new lines', () {
    expect(
      NusShoppingTextParser.parse('مشتريات: لبن، بيض, عيش\nمناديل'),
      <String>['لبن', 'بيض', 'عيش', 'مناديل'],
    );
  });

  test('does not split words that begin with و', () {
    expect(
      NusShoppingTextParser.parse('هات ورق و منظف'),
      <String>['ورق', 'منظف'],
    );
  });

  test('removes known request prefixes and de-duplicates items', () {
    expect(
      NusShoppingTextParser.parse('عايز أجيب لبن ولبن وبيض'),
      <String>['لبن', 'بيض'],
    );
  });
}
