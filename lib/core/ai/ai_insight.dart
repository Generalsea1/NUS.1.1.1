/// Provider-neutral output from future NUS intelligence features.
class AiInsight {
  const AiInsight({
    required this.id,
    required this.summary,
    required this.generatedAt,
    required this.sourceDomain,
  });

  final String id;
  final String summary;
  final DateTime generatedAt;
  final String sourceDomain;
}

/// Provider-neutral, read-only context supplied to an AI implementation.
class AiContextItem {
  const AiContextItem({
    required this.domain,
    required this.entityId,
    required this.summary,
  });

  final String domain;
  final String entityId;
  final String summary;
}

/// Provider-neutral AI request. The UI does not construct an SDK request.
class AiInsightRequest {
  const AiInsightRequest({
    required this.objective,
    required this.context,
  });

  final String objective;
  final List<AiContextItem> context;
}
