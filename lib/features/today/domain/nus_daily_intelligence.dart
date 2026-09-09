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

    final reminderIsToday = nextReminderAt != null &&
        DateUtils.isSameDay(nextReminderAt, today) &&
        nextReminderAt.isAfter(current);

    if (todayUpcoming.isNotEmpty || reminderIsToday) {
      final appointment = todayUpcoming.isEmpty ? null : todayUpcoming.first;
      final useReminder = reminderIsToday &&
          (appointment == null || nextReminderAt!.isBefore(appointment.startsAt));
      final title = useReminder ? nextReminderTitle : appointment!.title;
      final when = useReminder ? nextReminderAt! : appointment!.startsAt;
      final time = TimeOfDay.fromDateTime(when);
      insights.add(NusDailyInsight(
        title: useReminder ? 'عندك مهمة جاية النهارده' : 'عندك حاجة جاية النهارده',
        message: '${title ?? 'مهمة بدون اسم'} الساعة ${time.hour}:${time.minute.toString().padLeft(2, '0')}.',
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
