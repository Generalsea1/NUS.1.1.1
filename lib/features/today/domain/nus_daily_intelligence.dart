import 'package:flutter/material.dart';

import '../../appointments/domain/appointment.dart';
import '../../onboarding/domain/household_profile.dart';

class NusDailyInsight {
  const NusDailyInsight({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;
}

class NusDailyIntelligence {
  const NusDailyIntelligence._();

  static List<NusDailyInsight> build({
    required HouseholdProfile profile,
    required List<Appointment> appointments,
    int pendingReminderCount = 0,
    String? nextReminderTitle,
    DateTime? nextReminderAt,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateUtils.dateOnly(current);
    final insights = <NusDailyInsight>[];

    if (profile.remainingAfterObligations < 0) {
      insights.add(const NusDailyInsight(
        title: 'الميزانية محتاجة تركيز',
        message: 'الالتزامات الشهرية أعلى من الدخل المسجل. راجع الأرقام قبل أي التزام جديد.',
        icon: Icons.warning_amber_rounded,
      ));
    } else {
      insights.add(NusDailyInsight(
        title: 'مساحتك المالية الحالية',
        message: 'بعد الالتزامات المسجلة، المتاح هو ${profile.remainingAfterObligations} ${profile.currencyCode}.',
        icon: Icons.payments_outlined,
      ));
    }

    final todayUpcoming = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => DateUtils.isSameDay(item.startsAt, today))
        .where((item) => item.startsAt.isAfter(current))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final appointment = todayUpcoming.isEmpty ? null : todayUpcoming.first;
    DateTime? selectedWhen;
    String? selectedTitle;
    var useReminder = false;

    final reminderAt = nextReminderAt;
    if (reminderAt != null &&
        DateUtils.isSameDay(reminderAt, today) &&
        reminderAt.isAfter(current) &&
        (appointment == null || reminderAt.isBefore(appointment.startsAt))) {
      selectedWhen = reminderAt;
      selectedTitle = nextReminderTitle;
      useReminder = true;
    } else if (appointment != null) {
      selectedWhen = appointment.startsAt;
      selectedTitle = appointment.title;
    }

    if (selectedWhen != null) {
      final time = TimeOfDay.fromDateTime(selectedWhen);
      insights.add(NusDailyInsight(
        title: useReminder ? 'عندك مهمة جاية النهارده' : 'عندك حاجة جاية النهارده',
        message: '${selectedTitle ?? 'مهمة بدون اسم'} الساعة ${time.hour}:${time.minute.toString().padLeft(2, '0')}.',
        icon: useReminder ? Icons.check_circle_outline_rounded : Icons.event_available_rounded,
      ));
    } else {
      insights.add(const NusDailyInsight(
        title: 'اليوم هادي',
        message: 'مفيش موعد أو مهمة قادمة مسجلة النهارده. استغل المساحة في إنهاء أهم حاجة مؤجلة.',
        icon: Icons.wb_sunny_outlined,
      ));
    }

    final upcomingAppointmentsCount = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => item.startsAt.isAfter(current))
        .length;
    final upcomingWorkCount = upcomingAppointmentsCount + pendingReminderCount;
    if (upcomingWorkCount >= 3) {
      insights.add(NusDailyInsight(
        title: 'الأسبوع محتاج تنظيم',
        message: 'عندك $upcomingWorkCount موعد أو مهمة جاية. راجعهم وحدد أولوياتك بدل ما تسيبهم يتراكموا.',
        icon: Icons.calendar_month_rounded,
      ));
    }

    return insights.take(3).toList();
  }
}
