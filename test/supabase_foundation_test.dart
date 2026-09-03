import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/supabase_service.dart';

void main() {
  test('Supabase foundation is inert when build configuration is absent', () async {
    expect(SupabaseConfig.isConfigured, isFalse);
    expect(SupabaseService.isInitialized, isFalse);
    expect(SupabaseService.client, isNull);

    await SupabaseService.initialize();

    expect(SupabaseService.isInitialized, isFalse);
    expect(SupabaseService.client, isNull);
  });
}
