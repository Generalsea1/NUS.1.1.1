import 'package:flutter/material.dart';

import '../../../notification_service.dart';
import '../application/appointment_reminder_coordinator.dart';
import '../data/appointment_reminder_adapter.dart';
import '../data/local_appointment_repository.dart';
import '../domain/appointment.dart';
import 'appointment_details_page.dart';
import 'appointment_editor_page.dart';

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key, this.isArabic = true, this.repository, this.reminderCoordinator});
  final bool isArabic;
  final AppointmentRepository? repository;
  final AppointmentReminderCoordinator? reminderCoordinator;
  @override State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  late final AppointmentRepository _repository;
  late final AppointmentReminderCoordinator _reminders;
  List<Appointment> _items = [];
  bool _loading = true;
  AppointmentStatus? _filter;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalAppointmentRepository();
    _reminders = widget.reminderCoordinator ?? AppointmentReminderCoordinator(
      ReminderSchedulerAppointmentAdapter(NotificationService()),
    );
    _load();
  }

  Future<void> _load() async {
    final items = await _repository.list();
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _add() async {
    final appointment = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute(builder: (_) => AppointmentEditorPage(isArabic: widget.isArabic)),
    );
    if (!mounted || appointment == null) return;
    await _persist(appointment);
  }

  Future<void> _edit(Appointment appointment) async {
    final updated = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute(builder: (_) => AppointmentEditorPage(isArabic: widget.isArabic, initial: appointment)),
    );
    if (!mounted || updated == null) return;
    await _persist(updated);
  }

  Future<void> _persist(Appointment appointment) async {
    try {
      await _repository.save(appointment);
      await _reminders.sync(appointment);
      await _load();
    } on ArgumentError {
      _message(t('Invalid appointment data.', 'بيانات الموعد غير صحيحة.'));
    }
  }

  Future<void> _setStatus(Appointment appointment, AppointmentStatus status) async {
    final updated = appointment.copyWith(status: status);
    final errors = AppointmentValidator.validate(updated);
    if (errors.isNotEmpty) { _message(_validationMessage(errors.first)); return; }
    await _repository.save(updated);
    await _reminders.sync(updated);
    await _load();
  }

  Future<void> _delete(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Delete appointment?', 'تحذف الموعد؟')),
        content: Text(t('This action cannot be undone.', 'الإجراء ده لا يمكن التراجع عنه.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Delete', 'حذف'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _reminders.cancel(appointment.id);
    await _repository.deleteById(appointment.id);
    await _load();
  }

  Future<void> _details(Appointment appointment) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => AppointmentDetailsPage(isArabic: widget.isArabic, appointment: appointment)),
    );
    if (!mounted) return;
    if (result == AppointmentDetailsAction.edit) await _edit(appointment);
    else if (result == AppointmentDetailsAction.delete) await _delete(appointment);
    else if (result is AppointmentStatus) await _setStatus(appointment, result);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
  }

  String _validationMessage(String error) => switch (error) {
    'title_required' => t('Title is required.', 'اسم الموعد مطلوب.'),
    'end_after_start' => t('End time must be after start time.', 'وقت الانتهاء لازم يكون بعد وقت البداية.'),
    'start_must_be_future' => t('Upcoming appointments must be in the future.', 'الموعد القادم لازم يكون في المستقبل.'),
    'invalid_phone' => t('Enter a valid phone number.', 'اكتب رقم تليفون صحيح.'),
    'doctor_name_required' => t('Doctor name is required.', 'اسم الدكتور مطلوب.'),
    'follow_up_after_appointment' => t('Follow-up must be after the appointment.', 'المتابعة لازم تكون بعد الموعد.'),
    _ => t('Please review the appointment details.', 'راجع بيانات الموعد.'),
  };

  @override
  Widget build(BuildContext context) {
    final visible = _filter == null ? List<Appointment>.from(_items) : _items.where((item) => item.status == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t('Appointments', 'المواعيد'), style: const TextStyle(fontWeight: FontWeight.w900))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(t('New appointment', 'موعد جديد'))),
      body: SafeArea(
        child: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Text(t('Keep meetings, visits and important calls together.', 'خلي مواعيدك وزياراتك ومكالماتك المهمة كلها في مكان واحد.'), style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: [
                _Filter(label: t('All', 'الكل'), selected: _filter == null, onTap: () => setState(() => _filter = null)),
                _Filter(label: t('Upcoming', 'القادمة'), selected: _filter == AppointmentStatus.upcoming, onTap: () => setState(() => _filter = AppointmentStatus.upcoming)),
                _Filter(label: t('Completed', 'المكتملة'), selected: _filter == AppointmentStatus.completed, onTap: () => setState(() => _filter = AppointmentStatus.completed)),
                _Filter(label: t('Cancelled', 'الملغاة'), selected: _filter == AppointmentStatus.cancelled, onTap: () => setState(() => _filter = AppointmentStatus.cancelled)),
              ]),
              const SizedBox(height: 16),
              if (visible.isEmpty) _Empty(onAdd: _add, isArabic: widget.isArabic)
              else ...visible.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _AppointmentCard(item: item, isArabic: widget.isArabic, onTap: () => _details(item)))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.item, required this.isArabic, required this.onTap});
  final Appointment item; final bool isArabic; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final date = '${item.startsAt.day}/${item.startsAt.month}/${item.startsAt.year}';
    final time = TimeOfDay.fromDateTime(item.startsAt).format(context);
    final type = switch (item.type) {
      AppointmentType.personal => isArabic ? 'شخصي' : 'Personal',
      AppointmentType.doctor => isArabic ? 'طبيب' : 'Doctor',
      AppointmentType.work => isArabic ? 'عمل' : 'Work',
      AppointmentType.government => isArabic ? 'حكومي' : 'Government',
      AppointmentType.study => isArabic ? 'دراسة' : 'Study',
      AppointmentType.family => isArabic ? 'عائلة' : 'Family',
      AppointmentType.travel => isArabic ? 'سفر' : 'Travel',
      AppointmentType.phoneCall => isArabic ? 'مكالمة' : 'Phone call',
      AppointmentType.custom => isArabic ? 'مخصص' : 'Custom',
    };
    return Card(elevation: 0, child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Icon(item.type == AppointmentType.doctor ? Icons.medical_services_outlined : Icons.event_outlined)),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('$type  •  $date  •  $time'),
      trailing: const Icon(Icons.chevron_right_rounded),
    ));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd, required this.isArabic});
  final VoidCallback onAdd; final bool isArabic;
  @override Widget build(BuildContext context) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
    const Icon(Icons.event_available_rounded, size: 42), const SizedBox(height: 12),
    Text(isArabic ? 'لسه مفيش مواعيد' : 'No appointments yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text(isArabic ? 'سجّل أول موعد وخلي تفاصيله وتذكيره محفوظين.' : 'Create your first appointment and keep its details and reminder together.', textAlign: TextAlign.center),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: Text(isArabic ? 'إنشاء موعد' : 'Create appointment')),
  ])));
}
