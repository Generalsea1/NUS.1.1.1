import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/appointment.dart';

enum AppointmentDetailsAction { edit, delete }

class AppointmentDetailsPage extends StatelessWidget {
  const AppointmentDetailsPage({super.key, required this.appointment, this.isArabic = true});
  final Appointment appointment;
  final bool isArabic;
  String t(String en, String ar) => isArabic ? ar : en;

  Future<void> _call(BuildContext context) async {
    final raw = appointment.contactPhone;
    if (raw == null || !AppointmentValidator.isValidPhone(raw)) return;
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: AppointmentValidator.normalizePhone(raw)), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _message(context, t('Phone app is unavailable.', 'تطبيق الهاتف غير متاح.'));
    } on Object { if (context.mounted) _message(context, t('Could not open the phone app.', 'تعذر فتح تطبيق الهاتف.')); }
  }

  void _message(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final start = '${appointment.startsAt.day}/${appointment.startsAt.month}/${appointment.startsAt.year} • ${TimeOfDay.fromDateTime(appointment.startsAt).format(context)}';
    final phone = appointment.contactPhone;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Appointment details', 'تفاصيل الموعد'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: () => Navigator.pop(context, AppointmentDetailsAction.edit), icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: () => Navigator.pop(context, AppointmentDetailsAction.delete), icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(appointment.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _Info(title: t('Type', 'النوع'), value: _typeLabel(appointment.type)),
        _Info(title: t('When', 'الموعد'), value: start),
        if (appointment.endsAt != null) _Info(title: t('Ends', 'ينتهي'), value: '${appointment.endsAt!.day}/${appointment.endsAt!.month}/${appointment.endsAt!.year} • ${TimeOfDay.fromDateTime(appointment.endsAt!).format(context)}'),
        if ((appointment.location ?? '').isNotEmpty) _Info(title: t('Location', 'المكان'), value: appointment.location!),
        if ((appointment.contactName ?? '').isNotEmpty) _Info(title: t('Contact', 'جهة الاتصال'), value: appointment.contactName!),
        if (phone != null && phone.isNotEmpty) _Info(title: t('Phone', 'التليفون'), value: phone),
        _Info(title: t('Recurrence', 'التكرار'), value: _recurrenceLabel(appointment.recurrence)),
        _Info(title: t('Reminder', 'التذكير'), value: _reminderLabel(appointment.reminder)),
        if (appointment.isDoctor) ...[
          const SizedBox(height: 10), Text(t('Doctor details', 'بيانات الطبيب'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if ((appointment.doctorName ?? '').isNotEmpty) _Info(title: t('Doctor', 'الدكتور'), value: appointment.doctorName!),
          if ((appointment.specialty ?? '').isNotEmpty) _Info(title: t('Specialty', 'التخصص'), value: appointment.specialty!),
          if (appointment.followUpAt != null) _Info(title: t('Follow-up', 'المتابعة'), value: '${appointment.followUpAt!.day}/${appointment.followUpAt!.month}/${appointment.followUpAt!.year} • ${TimeOfDay.fromDateTime(appointment.followUpAt!).format(context)}'),
        ],
        if ((appointment.notes ?? '').isNotEmpty) _Info(title: t('Notes', 'ملاحظات'), value: appointment.notes!),
        if (appointment.status == AppointmentStatus.upcoming) ...[
          const SizedBox(height: 14),
          Row(children: [Expanded(child: FilledButton.icon(onPressed: () => Navigator.pop(context, AppointmentStatus.completed), icon: const Icon(Icons.check_rounded), label: Text(t('Complete', 'تم')))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context, AppointmentStatus.cancelled), icon: const Icon(Icons.close_rounded), label: Text(t('Cancel', 'إلغاء'))))]),
        ],
        if (phone != null && AppointmentValidator.isValidPhone(phone)) ...[
          const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => _call(context), icon: const Icon(Icons.call_outlined), label: Text(t('Call contact', 'اتصال بجهة الاتصال'))),
        ],
      ]),
    );
  }

  String _typeLabel(AppointmentType v) => switch (v) { AppointmentType.personal => t('Personal', 'شخصي'), AppointmentType.doctor => t('Doctor', 'طبيب'), AppointmentType.work => t('Work', 'عمل'), AppointmentType.government => t('Government', 'حكومي'), AppointmentType.study => t('Study', 'دراسة'), AppointmentType.family => t('Family', 'عائلة'), AppointmentType.travel => t('Travel', 'سفر'), AppointmentType.phoneCall => t('Phone call', 'مكالمة'), AppointmentType.custom => t('Custom', 'مخصص') };
  String _recurrenceLabel(AppointmentRecurrence v) => switch (v) { AppointmentRecurrence.none => t('Does not repeat', 'بدون تكرار'), AppointmentRecurrence.daily => t('Daily', 'يومي'), AppointmentRecurrence.weekly => t('Weekly', 'أسبوعي') };
  String _reminderLabel(AppointmentReminder v) => switch (v) { AppointmentReminder.none => t('No reminder', 'بدون تذكير'), AppointmentReminder.atTime => t('At appointment time', 'وقت الموعد'), AppointmentReminder.fiveMinutesBefore => t('5 minutes before', 'قبلها بـ 5 دقائق'), AppointmentReminder.fifteenMinutesBefore => t('15 minutes before', 'قبلها بـ 15 دقيقة'), AppointmentReminder.thirtyMinutesBefore => t('30 minutes before', 'قبلها بـ 30 دقيقة'), AppointmentReminder.oneHourBefore => t('1 hour before', 'قبلها بساعة'), AppointmentReminder.oneDayBefore => t('1 day before', 'قبلها بيوم') };
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.value});
  final String title, value;
  @override Widget build(BuildContext context) => Card(elevation: 0, child: ListTile(title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))));
}
