import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';

class UserAiRunRepository {
  const UserAiRunRepository();

  Future<List<Map<String, dynamic>>> recent({int limit = 20}) async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const [];
    final rows = await client
        .from('user_ai_runs')
        .select('id,provider,model,purpose,response,created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).toList(growable: false);
  }
}
