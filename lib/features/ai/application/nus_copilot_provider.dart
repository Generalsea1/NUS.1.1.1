import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../../core/supabase_service.dart';

class NusCopilotException implements Exception {
  const NusCopilotException({required this.message, this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

abstract interface class NusCopilotTransport {
  Future<Map<String, dynamic>> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  });
}

class SupabaseNusCopilotTransport implements NusCopilotTransport {
  const SupabaseNusCopilotTransport(this.client);
  final SupabaseClient client;

  @override
  Future<Map<String, dynamic>> invoke({required String accessToken, required Map<String, dynamic> body}) async {
    try {
      final response = await client.functions.invoke(
        'nus-copilot-ai',
        body: body,
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(const Duration(seconds: 35));
      final data = response.data;
      if (data is! Map) throw const NusCopilotException(message: 'وصل رد غير صالح من NUS Copilot.', statusCode: 422);
      return Map<String, dynamic>.from(data);
    } on TimeoutException {
      throw const NusCopilotException(message: 'انتهت مهلة NUS Copilot. حاول مرة أخرى.');
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] is String ? (details['error'] as String).trim() : '';
      throw NusCopilotException(statusCode: error.status, message: message.isEmpty ? 'تعذر الحصول على رد من NUS Copilot.' : message);
    } catch (error) {
      if (error is NusCopilotException) rethrow;
      throw const NusCopilotException(message: 'تعذر الاتصال بـNUS Copilot حاليًا.');
    }
  }
}

class NusCopilotProvider implements AiInsightProvider {
  const NusCopilotProvider({this.transport, this.accessTokenReader});

  final NusCopilotTransport? transport;
  final String? Function()? accessTokenReader;

  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    final client = SupabaseService.client;
    final accessToken = accessTokenReader?.call() ?? client?.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const NusCopilotException(message: 'يجب تسجيل الدخول لاستخدام NUS Copilot.', statusCode: 401);
    }
    final effective = transport ?? (client == null ? null : SupabaseNusCopilotTransport(client));
    if (effective == null) throw const NusCopilotException(message: 'خدمة NUS Copilot غير مُهيأة على هذه النسخة.', statusCode: 503);

    final data = await effective.invoke(
      accessToken: accessToken,
      body: {
        'objective': request.objective,
        'context': request.context.map((item) => <String, dynamic>{
          'domain': item.domain,
          'entityId': item.entityId,
          'summary': item.summary,
        }).toList(growable: false),
      },
    );
    if (data['ok'] != true) {
      throw NusCopilotException(message: data['error']?.toString() ?? 'NUS Copilot لم يُرجع نتيجة صالحة.', statusCode: (data['status'] as num?)?.toInt());
    }

    final id = data['id'];
    final summary = data['summary'];
    final generatedAt = data['generatedAt'];
    final facts = data['facts'];
    final advice = data['advice'];
    final warnings = data['warnings'];
    if (id is! String || id.trim().isEmpty || summary is! String || summary.trim().isEmpty || generatedAt is! String || DateTime.tryParse(generatedAt) == null || facts is! List || advice is! List || warnings is! List) {
      throw const NusCopilotException(message: 'رد NUS Copilot لا يطابق العقد المقرر.', statusCode: 422);
    }

    String section(String title, Object values) {
      if (values is! List || values.isEmpty) return '';
      final lines = values.whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty).map((value) => '• $value').join('\n');
      return lines.isEmpty ? '' : '$title\n$lines';
    }

    final sections = <String>[summary.trim()];
    for (final value in <String>[section('الحقائق', facts), section('النصيحة', advice), section('تنبيهات', warnings)]) {
      if (value.isNotEmpty) sections.add(value);
    }
    return AiInsight(id: id.trim(), summary: sections.join('\n\n'), generatedAt: DateTime.parse(generatedAt).toUtc(), sourceDomain: 'nus_copilot');
  }
}
