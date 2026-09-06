import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/supabase_service.dart';

void main() {
  test('startup auth does not run when Supabase configuration is invalid', () async {
    await SupabaseService.initialize();
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
