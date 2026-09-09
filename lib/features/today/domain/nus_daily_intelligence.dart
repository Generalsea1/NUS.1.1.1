import 'package:flutter/material.dart';

import '../../appointments/domain/appointment.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../onboarding/domain/household_profile.dart';

import 'nus_household_daily_brief.dart';

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
    int pendingShoppingItemCount = 0,
    String? nextReminderTitle,
    DateTime? nextReminderAt,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateUtils.dateOnly(current);
    final insights = <NusDailyInsight>[];

    final brief = NusHouseholdDailyBrief.build(
      profile: profile,
      appointments: appointments,
      pendingReminderCount: pendingReminderCount,
      pendingShoppingItemCount: pendingShoppingItemCount,
      monthlyActualExpenseMinorUnits: 0,
      monthlyIncomeMinorUnits: profile.monthlyIncome * _currencyScale(profile.currencyCode),
      monthlyObligationsMinorUnits: profile.recurringObligations * _currencyScale(profile.currencyCode),
      now: current,
    );
    insights.add(
      NusDailyInsight(
        title: brief.headline,
        message: '${brief.summary} ${brief.action}',
        icon: brief.icon,
      ),
    );

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

    if (pendingShoppingItemCount > 0 && insights.length < 3) {
      insights.add(NusDailyInsight(
        title: 'قائمة المشتريات مستنياك',
        message: 'عندك $pendingShoppingItemCount ${pendingShoppingItemCount == 1 ? 'عنصر' : 'عناصر'} لسه ما اتعملتش. خلّي مشوار الشراء واضح قبل ما تخرج.',
        icon: Icons.shopping_cart_outlined,
      ));
    }

    final upcomingAppointmentsCount = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => item.startsAt.isAfter(current))
        .length;
    final upcomingWorkCount = upcomingAppointmentsCount + pendingReminderCount;
    if (upcomingWorkCount >= 3 && insights.length < 3) {
      insights.add(NusDailyInsight(
        title: 'الأسبوع محتاج تنظيم',
        message: 'عندك $upcomingWorkCount موعد أو مهمة جاية. راجعهم وحدد أولوياتك بدل ما تسيبهم يتراكموا.',
        icon: Icons.calendar_month_rounded,
      ));
    }

    return insights.take(3).toList(growable: false);
  }

  static int _currencyScale(String currencyCode) {
    return CurrencyRegistry.get(currencyCode.trim().toUpperCase()).scale;
  }
}
