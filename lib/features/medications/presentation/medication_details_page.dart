import 'package:flutter/material.dart';

import '../domain/medication.dart';

enum MedicationDetailsAction { edit, delete, toggleActive }

class MedicationDetailsPage extends StatelessWidget {
  const MedicationDetailsPage({
    super.key,
    required this.medication,
    this.isArabic = true,
  });

  final Medication medication;
  final bool isArabic;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Medication details', 'تفاصيل الدواء'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: t('Edit', 'تعديل'),
            onPressed: () => Navigator.pop(context, MedicationDetailsAction.edit),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: t('Delete', 'حذف'),
            onPressed: () => Navigator.pop(context, MedicationDetailsAction.delete),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, child: const Icon(Icons.medication_outlined, size: 30)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(medication.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: SwitchListTile.adaptive(
              title: Text(medication.isActive ? t('Active', 'نشط') : t('Inactive', 'غير نشط'), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(medication.isActive
                  ? t('Reminders are synchronized for active schedules.', 'تذكيرات مواعيد الجرعات النشطة متزامنة.')
                  : t('Reminders are paused. Your medication data is preserved.', 'التذكيرات متوقفة وبيانات الدواء محفوظة.')),
              value: medication.isActive,
              onChanged: (_) => Navigator.pop(context, MedicationDetailsAction.toggleActive),
            ),
          ),
          _Info(title: t('Dosage', 'الجرعة'), value: _dosage()),
          if ((medication.instructions ?? '').isNotEmpty)
            _Info(title: t('Instructions', 'التعليمات'), value: medication.instructions!),
          if ((medication.notes ?? '').isNotEmpty)
            _Info(title: t('Notes', 'ملاحظات'), value: medication.notes!),
          _Info(title: t('Start date', 'تاريخ البداية'), value: _date(medication.startDate)),
          if (medication.endDate != null)
            _Info(title: t('End date', 'تاريخ الانتهاء'), value: _date(medication.endDate!)),
          const SizedBox(height: 8),
          Text(t('Schedules', 'مواعيد الجرعات'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...medication.schedules.map((schedule) => _ScheduleInfo(schedule: schedule, isArabic: isArabic)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, MedicationDetailsAction.toggleActive),
            icon: Icon(medication.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
            label: Text(medication.isActive ? t('Deactivate medication', 'إيقاف الدواء') : t('Activate medication', 'تفعيل الدواء')),
          ),
        ],
      ),
    );
  }

  String _dosage() {
    final unit = medication.dosage.unit == DosageUnit.custom
        ? (medication.dosage.customUnit ?? t('custom', 'مخصص'))
        : switch (medication.dosage.unit) {
            DosageUnit.tablet => t('tablet', 'قرص'),
            DosageUnit.capsule => t('capsule', 'كبسولة'),
            DosageUnit.ml => 'ml',
            DosageUnit.drop => t('drop', 'نقطة'),
            DosageUnit.puff => t('puff', 'بَخّة'),
            DosageUnit.injection => t('injection', 'حقنة'),
            DosageUnit.custom => t('custom', 'مخصص'),
          };
    return '${medication.dosage.amount} $unit';
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: ListTile(
          title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _ScheduleInfo extends StatelessWidget {
  const _ScheduleInfo({required this.schedule, required this.isArabic});

  final MedicationSchedule schedule;
  final bool isArabic;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(
      hour: schedule.minutesSinceMidnight ~/ 60,
      minute: schedule.minutesSinceMidnight % 60,
    ).format(context);
    final recurrence = schedule.frequency == MedicationFrequency.daily
        ? t('Daily', 'يومي')
        : schedule.selectedWeekdays.map(_weekday).join(isArabic ? '، ' : ', ');
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$recurrence • ${_reminder(schedule.reminder)}'),
      ),
    );
  }

  String _weekday(int value) => switch (value) {
        1 => t('Mon', 'الاثنين'),
        2 => t('Tue', 'الثلاثاء'),
        3 => t('Wed', 'الأربعاء'),
        4 => t('Thu', 'الخميس'),
        5 => t('Fri', 'الجمعة'),
        6 => t('Sat', 'السبت'),
        7 => t('Sun', 'الأحد'),
        _ => '?',
      };

  String _reminder(MedicationReminder reminder) => switch (reminder) {
        MedicationReminder.none => t('No reminder', 'بدون تذكير'),
        MedicationReminder.atTime => t('At time', 'في الموعد'),
        MedicationReminder.fiveMinutesBefore => t('5 minutes before', 'قبلها بـ 5 دقائق'),
        MedicationReminder.fifteenMinutesBefore => t('15 minutes before', 'قبلها بـ 15 دقيقة'),
        MedicationReminder.thirtyMinutesBefore => t('30 minutes before', 'قبلها بـ 30 دقيقة'),
        MedicationReminder.sixtyMinutesBefore => t('60 minutes before', 'قبلها بـ 60 دقيقة'),
        MedicationReminder.oneDayBefore => t('1 day before', 'قبلها بيوم'),
      };
}
