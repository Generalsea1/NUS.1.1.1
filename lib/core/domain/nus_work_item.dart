enum NusWorkItemKind {
  reminder,
  appointment,
  householdTask,
  obligation,
}

enum NusWorkItemPriority {
  critical,
  high,
  normal,
  low,
}

class NusWorkItem {
  const NusWorkItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.completed,
    required this.priority,
    this.dueAt,
    this.amountMinorUnits,
    this.currencyCode,
  });

  final String id;
  final String title;
  final NusWorkItemKind kind;
  final bool completed;
  final NusWorkItemPriority priority;
  final DateTime? dueAt;
  final int? amountMinorUnits;
  final String? currencyCode;

  bool get isOverdue {
    final due = dueAt;
    if (completed || due == null) return false;
    return due.isBefore(DateTime.now());
  }

  NusWorkItem copyWith({
    String? title,
    NusWorkItemKind? kind,
    bool? completed,
    NusWorkItemPriority? priority,
    DateTime? dueAt,
    bool clearDueAt = false,
    int? amountMinorUnits,
    bool clearAmount = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
  }) {
    return NusWorkItem(
      id: id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      amountMinorUnits: clearAmount ? null : amountMinorUnits ?? this.amountMinorUnits,
      currencyCode: clearCurrencyCode ? null : currencyCode ?? this.currencyCode,
    );
  }
}

class NusWorkQueue {
  const NusWorkQueue._();

  static List<NusWorkItem> active(Iterable<NusWorkItem> items) {
    final result = items.where((item) => !item.completed).toList(growable: false);
    final sorted = [...result];
    sorted.sort(_compare);
    return List<NusWorkItem>.unmodifiable(sorted);
  }

  static int pendingCount(Iterable<NusWorkItem> items) => items.where((item) => !item.completed).length;

  static NusWorkItem? next(Iterable<NusWorkItem> items) {
    final activeItems = active(items);
    return activeItems.isEmpty ? null : activeItems.first;
  }

  static int _compare(NusWorkItem left, NusWorkItem right) {
    final leftBucket = _dueBucket(left);
    final rightBucket = _dueBucket(right);
    if (leftBucket != rightBucket) return leftBucket.compareTo(rightBucket);

    final priority = left.priority.index.compareTo(right.priority.index);
    if (priority != 0) return priority;

    final leftDue = left.dueAt;
    final rightDue = right.dueAt;
    if (leftDue != null && rightDue != null) {
      final due = leftDue.compareTo(rightDue);
      if (due != 0) return due;
    } else if (leftDue != null) {
      return -1;
    } else if (rightDue != null) {
      return 1;
    }

    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  }

  static int _dueBucket(NusWorkItem item) {
    final due = item.dueAt;
    if (due == null) return 3;
    final now = DateTime.now();
    if (due.isBefore(now)) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (due.isBefore(tomorrow)) return 1;
    return 2;
  }
}
