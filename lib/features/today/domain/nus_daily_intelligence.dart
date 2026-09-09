import '../../appointments/domain/appointment.dart';
import '../../onboarding/domain/household_profile.dart';

class NusDailyInsight {
  const NusDailyInsight({
    required this.title,
    required this.message,
    required this.iconCodePoint,
  });

  final String title;
  final String message;
  final int iconCodePoint;
}

class NusDailyIntelligence {
  const NusDailyIntelligence._();

  static List<NusDailyInsight> build({
    required HouseholdProfile profile,
    required List<Appointment> appointments,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final insights = <NusDailyInsight>[];

    if (profile.remainingAfterObligations < 0) {
      insights.add(const NusDailyInsight(
        title: 'الميزانية محتاجة تركيز',
        message: 'الالتزامات الشهرية أعلى من الدخل المسجل. راجع الأرقام قبل أي التزام جديد.',
        iconCodePoint: 0xe8e8,
      ));
    } else {
      insights.add(NusDailyInsight(
        title: 'مساحتك المالية الحالية',
        message: 'بعد الالتزامات المسجلة، المتاح هو ${profile.remainingAfterObligations} ${profile.currencyCode}.',
        iconCodePoint: 0xe8e0,
      ));
    }

    final todayUpcoming = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => DateUtils.isSameDay(item.startsAt, today))
        .where((item) => item.startsAt.isAfter(current))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (todayUpcoming.isNotEmpty) {
      final next = todayUpcoming.first;
      insights.add(NusDailyInsight(
        title: 'عندك حاجة جاية النهارده',
        message: '${next.title} الساعة ${TimeOfDay.fromDateTime(next.startsAt).format(_ContextlessTimeFormat.context)}.',
        iconCodePoint: 0xe878,
      ));
    } else {
      insights.add(const NusDailyInsight(
        title: 'اليوم هادي',
        message: 'مفيش موعد قادم مسجل النهارده. استغل المساحة في إنهاء أهم حاجة مؤجلة.',
        iconCodePoint: 0xe8b8,
      ));
    }

    final upcoming = appointments
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => item.startsAt.isAfter(current))
        .toList();
    if (upcoming.length >= 3) {
      insights.add(NusDailyInsight(
        title: 'الأسبوع محتاج تنظيم',
        message: 'عندك ${upcoming.length} مواعيد جاية. راجعها مرة واحدة وحدد أولوياتك.',
        iconCodePoint: 0xe8b5,
      ));
    }

    return insights.take(3).toList();
  }
}

class _ContextlessTimeFormat {
  const _ContextlessTimeFormat._();
  static const context = _MaterialLocalizationsProxy();
}

class _MaterialLocalizationsProxy implements dynamic {
  const _MaterialLocalizationsProxy();
  String format(TimeOfDay time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
}
