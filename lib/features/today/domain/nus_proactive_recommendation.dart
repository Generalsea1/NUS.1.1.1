enum NusRecommendationPriority { normal, high, critical }

enum NusRecommendationAction { reviewSpending, prepareAppointment, organizeDay, reviewShopping }

class NusProactiveRecommendation {
  const NusProactiveRecommendation({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.action,
  });

  final String id;
  final String title;
  final String message;
  final NusRecommendationPriority priority;
  final NusRecommendationAction action;
}

/// Produces small, explainable actions from facts already known by NUS.
/// It never calls AI, persists data, or invents missing values.
class NusProactiveRecommendationEngine {
  const NusProactiveRecommendationEngine._();

  static List<NusProactiveRecommendation> build({
    required DateTime now,
    required int pendingReminderCount,
    required int todayAppointmentCount,
    required int pendingShoppingItemCount,
    required bool financialPressure,
    DateTime? nextAppointmentAt,
    String? nextAppointmentTitle,
  }) {
    final recommendations = <NusProactiveRecommendation>[];

    if (financialPressure) {
      recommendations.add(
        const NusProactiveRecommendation(
          id: 'review-finances',
          title: 'راجع فلوس الشهر',
          message: 'في ضغط مالي مسجل. الأفضل تراجع الالتزامات والإنفاق قبل أي التزام جديد.',
          priority: NusRecommendationPriority.critical,
          action: NusRecommendationAction.reviewSpending,
        ),
      );
    }

    final workload = pendingReminderCount + todayAppointmentCount;
    if (workload >= 3) {
      recommendations.add(
        const NusProactiveRecommendation(
          id: 'organize-day',
          title: 'نظّم يومك قبل ما يبدأ',
          message: 'عندك أكتر من مهمة أو موعد قريب. رتّب الأولويات وحدد أهم حاجة لازم تخلصها أولًا.',
          priority: NusRecommendationPriority.high,
          action: NusRecommendationAction.organizeDay,
        ),
      );
    }

    if (nextAppointmentAt != null && nextAppointmentAt.isAfter(now)) {
      final title = (nextAppointmentTitle ?? '').trim();
      recommendations.add(
        NusProactiveRecommendation(
          id: 'prepare-next-appointment',
          title: 'استعد للموعد الجاي',
          message: title.isEmpty
              ? 'عندك موعد قادم. جهّز المكان أو الأوراق اللازمة قبل وقته.'
              : 'جهّز نفسك لموعد "$title" قبل ${_clock(nextAppointmentAt)}.',
          priority: NusRecommendationPriority.high,
          action: NusRecommendationAction.prepareAppointment,
        ),
      );
    }

    if (pendingShoppingItemCount > 0) {
      recommendations.add(
        NusProactiveRecommendation(
          id: 'finish-shopping',
          title: 'كمّل قائمة المشتريات',
          message: 'عندك $pendingShoppingItemCount ${pendingShoppingItemCount == 1 ? 'حاجة' : 'حاجات'} لسه محتاجة تتجاب.',
          priority: NusRecommendationPriority.normal,
          action: NusRecommendationAction.reviewShopping,
        ),
      );
    }

    final priority = <NusRecommendationPriority, int>{
      NusRecommendationPriority.critical: 3,
      NusRecommendationPriority.high: 2,
      NusRecommendationPriority.normal: 1,
    };
    recommendations.sort((a, b) {
      final priorityCompare = priority[b.priority]!.compareTo(priority[a.priority]!);
      if (priorityCompare != 0) return priorityCompare;
      return a.id.compareTo(b.id);
    });

    return List.unmodifiable(recommendations.take(3));
  }

  static String _clock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
