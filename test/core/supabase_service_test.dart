import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/supabase_service.dart';

void main() {
  test('Supabase config validation rejects missing provider credentials', () {
    expect(
      SupabaseConfig.isValid(url: '', publishableKey: ''),
      isFalse,
    );
  });

  test('Supabase config validation accepts a valid HTTPS endpoint and key', () {
    expect(
      SupabaseConfig.isValid(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_test',
      ),
      isTrue,
    );
  });
}
