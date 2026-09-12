import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/domain/nus_work_item.dart';

void main() {
  group('NusWorkQueue', () {
    final now = DateTime.now();

    test('excludes completed work from active queue', () {
      final items = [
        NusWorkItem(
          id: 'done',
          title: 'Done',
          kind: NusWorkItemKind.reminder,
          completed: true,
          priority: NusWorkItemPriority.critical,
          dueAt: now.subtract(const Duration(minutes: 5)),
        ),
        NusWorkItem(
          id: 'open',
          title: 'Open',
          kind: NusWorkItemKind.householdTask,
          completed: false,
          priority: NusWorkItemPriority.normal,
          dueAt: now.add(const Duration(hours: 1)),
        ),
      ];

      expect(NusWorkQueue.pendingCount(items), 1);
      expect(NusWorkQueue.active(items).single.id, 'open');
    });

    test('prioritizes overdue before today, upcoming and undated work', () {
      final items = [
        NusWorkItem(
          id: 'undated',
          title: 'Undated',
          kind: NusWorkItemKind.obligation,
          completed: false,
          priority: NusWorkItemPriority.critical,
        ),
        NusWorkItem(
          id: 'upcoming',
          title: 'Upcoming',
          kind: NusWorkItemKind.appointment,
          completed: false,
          priority: NusWorkItemPriority.critical,
          dueAt: now.add(const Duration(days: 2)),
        ),
        NusWorkItem(
          id: 'today',
          title: 'Today',
          kind: NusWorkItemKind.reminder,
          completed: false,
          priority: NusWorkItemPriority.normal,
          dueAt: DateTime(now.year, now.month, now.day, 23, 0),
        ),
        NusWorkItem(
          id: 'overdue',
          title: 'Overdue',
          kind: NusWorkItemKind.householdTask,
          completed: false,
          priority: NusWorkItemPriority.low,
          dueAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

      expect(
        NusWorkQueue.active(items).map((item) => item.id),
        ['overdue', 'today', 'upcoming', 'undated'],
      );
    });

    test('uses priority before due time inside the same urgency bucket', () {
      final items = [
        NusWorkItem(
          id: 'normal',
          title: 'Normal',
          kind: NusWorkItemKind.reminder,
          completed: false,
          priority: NusWorkItemPriority.normal,
          dueAt: now.add(const Duration(minutes: 5)),
        ),
        NusWorkItem(
          id: 'critical',
          title: 'Critical',
          kind: NusWorkItemKind.obligation,
          completed: false,
          priority: NusWorkItemPriority.critical,
          dueAt: now.add(const Duration(minutes: 30)),
        ),
      ];

      expect(NusWorkQueue.next(items)?.id, 'critical');
    });
  });
}
