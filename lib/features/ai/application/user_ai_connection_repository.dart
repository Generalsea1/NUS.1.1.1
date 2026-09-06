import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';

class UserAiConnection {
  const UserAiConnection({required this.provider, required this.status, this.model});

  final String provider;
  final String status;
  final String? model;

  bool get isConnected => status == 'connected';
}

class UserAiConnectionRepository {
  const UserAiConnectionRepository();

  SupabaseClient? get _client => SupabaseService.client;

  Future<List<UserAiConnection>> list() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const [];
    final rows = await client
        .from('user_ai_connections')
        .select('provider,status,model')
        .eq('user_id', user.id);
    return (rows as List)
        .map((row) => UserAiConnection(
              provider: row['provider'] as String,
              status: row['status'] as String? ?? 'disconnected',
              model: row['model'] as String?,
            ))
        .toList(growable: false);
  }
}
