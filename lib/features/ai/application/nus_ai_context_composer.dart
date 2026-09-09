import '../../../core/ai/ai_insight.dart';

class NusAiContextComposer {
  const NusAiContextComposer._();

  static const supportedDomains = <String>{
    'household',
    'calendar',
    'tasks',
    'shopping',
    'finance',
    'health',
    'documents',
  };

  static AiInsightRequest compose({
    required String objective,
    required Iterable<AiContextItem> context,
    Set<String>? allowedDomains,
    int maxItems = 20,
  }) {
    final cleanObjective = objective.trim();
    if (cleanObjective.isEmpty) {
      throw ArgumentError.value(objective, 'objective', 'AI objective is required.');
    }
    if (maxItems <= 0) {
      throw ArgumentError.value(maxItems, 'maxItems', 'maxItems must be positive.');
    }

    final requestedDomains = allowedDomains ?? supportedDomains;
    final cleanDomains = requestedDomains
        .map((domain) => domain.trim().toLowerCase())
        .where(supportedDomains.contains)
        .toSet();

    final unique = <String, AiContextItem>{};
    for (final item in context) {
      final domain = item.domain.trim().toLowerCase();
      final entityId = item.entityId.trim();
      final summary = item.summary.trim();
      if (!cleanDomains.contains(domain) || entityId.isEmpty || summary.isEmpty) continue;

      final normalized = AiContextItem(
        domain: domain,
        entityId: entityId,
        summary: summary,
      );
      unique.putIfAbsent('$domain::$entityId', () => normalized);
    }

    final items = unique.values.toList()
      ..sort((a, b) {
        final byDomain = a.domain.compareTo(b.domain);
        if (byDomain != 0) return byDomain;
        return a.entityId.compareTo(b.entityId);
      });

    return AiInsightRequest(
      objective: cleanObjective,
      context: List<AiContextItem>.unmodifiable(items.take(maxItems)),
    );
  }
}
