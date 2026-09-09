import 'package:flutter/foundation.dart';

class NusProactiveNotification {
  const NusProactiveNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime scheduledAt;
}

/// Deterministic notification-intent planner. It never invents data and never
/// sends notifications itself; delivery remains behind ReminderScheduler.
class NusProactiveNotificationPlanner {
  const NusProactiveNotificationPlanner({this.maxItems = 3});

  final int maxItems;

  List<NusProactiveNotification> plan({
    required DateTime now,
    required Iterable<NusProactiveSignal> signals,
  }) {
    final candidates = <NusProactiveNotification>[];
    for (final signal in signals) {
      if (!signal.enabled || !signal.scheduledAt.isAfter(now)) continue;
      candidates.add(NusProactiveNotification(
        id: 'proactive:${signal.id}',
        title: signal.title,
        body: signal.body,
        scheduledAt: signal.scheduledAt,
      ));
    }
    candidates.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    if (candidates.length <= maxItems) return candidates;
    return candidates.sublist(0, maxItems);
  }
}

@immutable
class NusProactiveSignal {
  const NusProactiveSignal({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final bool enabled;
}
