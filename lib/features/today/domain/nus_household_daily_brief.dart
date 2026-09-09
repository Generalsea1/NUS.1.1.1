import 'package:flutter/material.dart';

import '../../appointments/domain/appointment.dart';
import '../../onboarding/domain/household_profile.dart';

/// A deterministic, read-only morning brief assembled from already-authoritative
/// NUS domains. It deliberately avoids inventing financial values or persisting
/// anything; provider-backed AI can enrich it later through the AI boundary.
class NusHouseholdDailyBrief {
  const NusHouseholdDailyBrief({
    required this.headline,
    required this.summary,
    required this.priority,
    required this.action,
    required this.icon,
  });

  final String headline;
  final String summary;
  final String priority;
  final String action;
  final IconData icon;

  static NusHouseholdDailyBrief build({
    required HouseholdProfile profile,
    required List<Appointment> appointments,
    required int pendingReminderCount,
    required int pendingShoppingItemCount,
    required int monthlyActualExpenseMinorUnits,
    required int monthlyIncomeMinorUnits,
    required int monthlyObligationsMinorUnits,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateUtils.dateOnly(current);
    final todayAppointments = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => DateUtils.isSameDay(item.startsAt, today))
        .where((item) => item.startsAt.isAfter(current))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final available = monthlyIncomeMinorUnits - monthlyObligationsMinorUnits - monthlyActualExpenseMinorUnits;
    final pressure = available < 0;
    final workload = pendingReminderCount + todayAppointments.length;

    if (pressure) {
      return NusHouseholdDailyBrief(
        headline: 'النهارده محتاج حماية للسيولة',
        summary: 'البيانات الحالية بتقول إن الالتزامات والإنفاق المسجلين ضغطوا المساحة المتاحة.',
        priority: 'مالي',
        action: 'راجع أقرب التزامات ومصروفات قبل ما تضيف التزام جديد.',
        icon: Icons.shield_outlined,
      );
    }

    if (workload >= 3) {
      return NusHouseholdDailyBrief(
        headline: 'ابدأ بأعلى أولوية',
        summary: 'عندك $workload عناصر عمل قريبة النهارده بين مواعيد ومهام.',
        priority: 'تنظيم',
        action: todayAppointments.isNotEmpty
            ? 'ابدأ بموعدك الأقرب ثم اقفل مهمة واحدة بعدها.'
            : 'اقفل مهمة واحدة الآن بدل توزيع تركيزك على كل العناصر.',
        icon: Icons.flag_outlined,
      );
    }

    if (pendingShoppingItemCount > 0) {
      return NusHouseholdDailyBrief(
        headline: 'المشتريات جاهزة للخطوة التالية',
        summary: 'عندك $pendingShoppingItemCount عنصر في قائمة الشراء، من الأفضل تجمع المشوار في مرة واحدة.',
        priority: 'البيت',
        action: 'راجع القائمة قبل الخروج وحدد الضروري أولًا.',
        icon: Icons.shopping_bag_outlined,
      );
    }

    if (todayAppointments.isNotEmpty) {
      final next = todayAppointments.first;
      final time = TimeOfDay.fromDateTime(next.startsAt);
      return NusHouseholdDailyBrief(
        headline: 'موعدك الأقرب هو نقطة البداية',
        summary: '${next.title} الساعة ${time.hour}:${time.minute.toString().padLeft(2, '0')}.',
        priority: 'اليوم',
        action: 'جهز للموعد بدري وسيب مساحة بعده لباقي اليوم.',
        icon: Icons.event_note_outlined,
      );
    }

    final currency = profile.currencyCode;
    return NusHouseholdDailyBrief(
      headline: 'ابدأ بحاجة صغيرة محسوبة',
      summary: available >= 0
          ? 'المساحة الحالية بعد الالتزامات والإنفاق المسجل ما زالت غير سالبة.'
          : 'المتاح الحالي سلبي ويحتاج مراجعة البيانات.',
      priority: 'توازن',
      action: 'سجل أول خطوة مهمة في يومك من إضافة سريعة.',
      icon: Icons.wb_sunny_outlined,
    );
  }
}
