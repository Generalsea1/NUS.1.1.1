import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../../core/supabase_service.dart';

class FinancialAdvisorUnavailableException implements Exception {
  const FinancialAdvisorUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum FinancialAdvisorFailureKind {
  authentication,
  backendUnavailable,
  providerUnavailable,
  malformedResponse,
  timeout,
  rateLimited,
}

class FinancialAdvisorException implements Exception {
  const FinancialAdvisorException({required this.kind, required this.message, this.statusCode});
  final FinancialAdvisorFailureKind kind;
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class FinancialAdvisorTransportResponse {
  const FinancialAdvisorTransportResponse({required this.statusCode, required this.data});
  final int statusCode;
  final dynamic data;
}

abstract interface class FinancialAdvisorTransport {
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  });
}

class SupabaseFinancialAdvisorTransport implements FinancialAdvisorTransport {
  const SupabaseFinancialAdvisorTransport(this.client);
  final SupabaseClient client;

  @override
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await client.functions
          .invoke(
            'financial-advisor-ai',
            body: body,
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 35));
      return FinancialAdvisorTransportResponse(statusCode: response.status, data: response.data);
    } on TimeoutException {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.timeout,
        message: 'انتهت مهلة الاتصال بالمستشار المالي. حاول مرة أخرى.',
      );
    } on FunctionException catch (error) {
      throw _fromFunctionException(error);
    } catch (_) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.backendUnavailable,
        message: 'تعذر الاتصال بخدمة المستشار المالي. حاول مرة أخرى.',
      );
    }
  }

  FinancialAdvisorException _fromFunctionException(FunctionException error) {
    final message = _errorMessage(error.details);
    switch (error.status) {
      case 401:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.authentication,
          statusCode: error.status,
          message: message ?? 'يجب تسجيل الدخول لاستخدام المستشار المالي.',
        );
      case 409:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.providerUnavailable,
          statusCode: error.status,
          message: message ?? 'اربط حساب Gemini أولًا لاستخدام المستشار المالي.',
        );
      case 429:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.rateLimited,
          statusCode: error.status,
          message: message ?? 'تم الوصول إلى حد الاستخدام مؤقتًا. حاول بعد قليل.',
        );
      case 422:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.malformedResponse,
          statusCode: error.status,
          message: message ?? 'وصل رد غير صالح من خدمة الذكاء الاصطناعي.',
        );
      case 502:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.providerUnavailable,
          statusCode: error.status,
          message: message ?? 'خدمة Gemini غير متاحة حاليًا.',
        );
      case 503:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.backendUnavailable,
          statusCode: error.status,
          message: message ?? 'خدمة المستشار المالي غير متاحة حاليًا.',
        );
      case 504:
        return FinancialAdvisorException(
          kind: FinancialAdvisorFailureKind.timeout,
          statusCode: error.status,
          message: message ?? 'انتهت مهلة خدمة المستشار المالي.',
        );
      default:
        return FinancialAdvisorException(
          kind: error.status >= 500
              ? FinancialAdvisorFailureKind.backendUnavailable
              : FinancialAdvisorFailureKind.providerUnavailable,
          statusCode: error.status,
          message: message ?? 'تعذر الحصول على رد من المستشار المالي.',
        );
    }
  }

  String? _errorMessage(dynamic details) {
    if (details is Map && details['error'] is String) {
      final value = (details['error'] as String).trim();
      return value.isEmpty ? null : value;
    }
    if (details is String && details.trim().isNotEmpty) return details.trim();
    return null;
  }
}

/// Real read-only production provider for the Financial Advisor.
/// The request comes only from the existing Financial Engine snapshot.
class FinancialAdvisorProvider implements AiInsightProvider {
  const FinancialAdvisorProvider({this.transport, this.accessTokenReader});

  final FinancialAdvisorTransport? transport;
  final String? Function()? accessTokenReader;

  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    final client = SupabaseService.client;
    final accessToken = accessTokenReader?.call() ?? client?.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.authentication,
        message: 'يجب تسجيل الدخول لاستخدام المستشار المالي.',
      );
    }

    final effectiveTransport = transport ??
        (client == null ? null : SupabaseFinancialAdvisorTransport(client));
    if (effectiveTransport == null) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.backendUnavailable,
        message: 'خدمة المستشار المالي غير مُهيأة على هذه النسخة.',
      );
    }

    final response = await effectiveTransport.invoke(
      accessToken: accessToken,
      body: {
        'objective': request.objective,
        'context': request.context
            .map((item) => {
                  'domain': item.domain,
                  'entityId': item.entityId,
                  'summary': item.summary,
                })
            .toList(growable: false),
      },
    );

    return _parseResponse(response.data);
  }

  AiInsight _parseResponse(dynamic data) {
    if (data is! Map) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.malformedResponse,
        message: 'وصل رد غير صالح من خدمة المستشار المالي.',
      );
    }
    final payload = Map<String, dynamic>.from(data);
    if (payload['ok'] != true) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.providerUnavailable,
        message: 'خدمة المستشار المالي لم تُرجع نتيجة صالحة.',
      );
    }

    final id = payload['id'];
    final summary = payload['summary'];
    final generatedAt = payload['generatedAt'];
    final facts = _stringList(payload['facts']);
    final advice = _stringList(payload['advice']);
    final warnings = _stringList(payload['warnings']);

    if (id is! String || id.trim().isEmpty ||
        summary is! String || summary.trim().isEmpty ||
        generatedAt is! String || DateTime.tryParse(generatedAt) == null ||
        facts == null || advice == null || warnings == null) {
      throw const FinancialAdvisorException(
        kind: FinancialAdvisorFailureKind.malformedResponse,
        message: 'رد المستشار المالي لا يطابق العقد المقرر.',
      );
    }

    final sections = <String>[
      summary.trim(),
      if (facts.isNotEmpty) 'الحقائق\n${facts.map((value) => '• $value').join('\n')}',
      if (advice.isNotEmpty) 'النصيحة\n${advice.map((value) => '• $value').join('\n')}',
      if (warnings.isNotEmpty) 'تنبيهات\n${warnings.map((value) => '• $value').join('\n')}',
    ];

    return AiInsight(
      id: id.trim(),
      summary: sections.join('\n\n'),
      generatedAt: DateTime.parse(generatedAt).toUtc(),
      sourceDomain: 'financial_advisor',
    );
  }

  List<String>? _stringList(dynamic value) {
    if (value is! List) return null;
    final result = <String>[];
    for (final item in value) {
      if (item is! String || item.trim().isEmpty) return null;
      result.add(item.trim());
    }
    return List<String>.unmodifiable(result);
  }
}