import 'package:flutter/material.dart';

import '../domain/appointment.dart';

class AppointmentEditorPage extends StatefulWidget {
  const AppointmentEditorPage({super.key, this.initial, this.isArabic = true});
  final Appointment? initial;
  final bool isArabic;
  @override State<AppointmentEditorPage> createState() => _AppointmentEditorPageState();
}

class _AppointmentEditorPageState extends State<AppointmentEditorPage> {
  late final TextEditingController _title, _location, _notes, _contactName, _contactPhone, _doctorName, _specialty;
  late DateTime _startsAt;
  DateTime? _endsAt, _followUpAt;
  late AppointmentType _type;
  late AppointmentRecurrence _recurrence;
  late AppointmentReminder _reminder;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    _title = TextEditingController(text: a?.title ?? '');
    _location = TextEditingController(text: a?.location ?? '');
    _notes = TextEditingController(text: a?.notes ?? '');
    _contactName = TextEditingController(text: a?.contactName ?? '');
    _contactPhone = TextEditingController(text: a?.contactPhone ?? '');
    _doctorName = TextEditingController(text: a?.doctorName ?? '');
    _specialty = TextEditingController(text: a?.specialty ?? '');
    _startsAt = a?.startsAt ?? DateTime.now().add(const Duration(minutes: 30));
    _endsAt = a?.endsAt;
    _followUpAt = a?.followUpAt;
    _type = a?.type ?? AppointmentType.personal;
    _recurrence = a?.recurrence ?? AppointmentRecurrence.none;
    _reminder = a?.reminder ?? AppointmentReminder.fifteenMinutesBefore;
  }

  @override
  void dispose() {
    _title.dispose(); _location.dispose(); _notes.dispose(); _contactName.dispose(); _contactPhone.dispose(); _doctorName.dispose(); _specialty.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateUtils.dateOnly(now), lastDate: now.add(const Duration(days: 3650)), initialDate: _startsAt.isBefore(now) ? now : _startsAt);
    if (d == null || !mounted) return;
    setState(() => _startsAt = DateTime(d.year, d.month, d.day, _startsAt.hour, _startsAt.minute));
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startsAt));
    if (picked == null || !mounted) return;
    setState(() => _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day, picked.hour, picked.minute));
  }

  Future<void> _pickDateTime({required DateTime initial, required DateTime first, required ValueChanged<DateTime> onPicked}) async {
    final d = await showDatePicker(context: context, firstDate: DateUtils.dateOnly(first), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: initial.isBefore(first) ? first : initial);
    if (d == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    onPicked(DateTime(d.year, d.month, d.day, time.hour, time.minute));
  }

  void _save() {
    final a = widget.initial;
    final appointment = Appointment(id: a?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), title: _title.text.trim(), type: _type, startsAt: _startsAt, endsAt: _endsAt, location: _clean(_location.text), notes: _clean(_notes.text), contactName: _clean(_contactName.text), contactPhone: _clean(_contactPhone.text), recurrence: _recurrence, reminder: _reminder, status: a?.status ?? AppointmentStatus.upcoming, doctorName: _type == AppointmentType.doctor ? _clean(_doctorName.text) : null, specialty: _type == AppointmentType.doctor ? _clean(_specialty.text) : null, followUpAt: _type == AppointmentType.doctor ? _followUpAt : null);
    final errors = AppointmentValidator.validate(appointment);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error(errors.first))));
      return;
    }
    Navigator.of(context).pop(appointment);
  }

  String? _clean(String value) => value.trim().isEmpty ? null : value.trim();
  String _error(String value) => switch (value) {
    'title_required' => t('Title is required.', 'اسم الموعد مطلوب.'),
    'end_after_start' => t('End time must be after start time.', 'وقت الانتهاء لازم يكون بعد وقت البداية.'),
    'start_must_be_future' => t('The appointment must be in the future.', 'الموعد لازم يكون في المستقبل.'),
    'invalid_phone' => t('Enter a valid phone number.', 'اكتب رقم تليفون صحيح.'),
    'doctor_name_required' => t('Doctor name is required.', 'اسم الدكتور مطلوب.'),
    'follow_up_after_appointment' => t('Follow-up must be after the appointment.', 'المتابعة لازم تكون بعد الموعد.'),
    _ => t('Please review the details.', 'راجع البيانات.'),
  };

  @override
  Widget build(BuildContext context) {
    final doctor = _type == AppointmentType.doctor;
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? t('New appointment', 'موعد جديد') : t('Edit appointment', 'تعديل الموعد'), style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        TextField(controller: _title, autofocus: widget.initial == null, decoration: InputDecoration(labelText: t('Title *', 'اسم الموعد *'), prefixIcon: const Icon(Icons.title_rounded))),
        const SizedBox(height: 12),
        DropdownButtonFormField<AppointmentType>(initialValue: _type, decoration: InputDecoration(labelText: t('Type', 'النوع')), items: AppointmentType.values.map((v) => DropdownMenuItem(value: v, child: Text(_typeLabel(v)))).toList(), onChanged: (v) => setState(() => _type = v ?? AppointmentType.personal)),
        const SizedBox(height: 16),
        Text(t('Date & time', 'التاريخ والوقت'), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _pickStartDate, icon: const Icon(Icons.calendar_today_outlined), label: Text('${_startsAt.day}/${_startsAt.month}/${_startsAt.year}'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: _pickStartTime, icon: const Icon(Icons.schedule_outlined), label: Text(TimeOfDay.fromDateTime(_startsAt).format(context))))]),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => _pickDateTime(initial: _endsAt ?? _startsAt.add(const Duration(hours: 1)), first: _startsAt, onPicked: (v) => setState(() => _endsAt = v)), icon: const Icon(Icons.timelapse_outlined), label: Text(_endsAt == null ? t('Add end time', 'إضافة وقت انتهاء') : '${_endsAt!.day}/${_endsAt!.month}/${_endsAt!.year} • ${TimeOfDay.fromDateTime(_endsAt!).format(context)}')),
        if (_endsAt != null) TextButton(onPressed: () => setState(() => _endsAt = null), child: Text(t('Clear end time', 'مسح وقت الانتهاء'))),
        TextField(controller: _location, decoration: InputDecoration(labelText: t('Location', 'المكان'), prefixIcon: const Icon(Icons.place_outlined))),
        const SizedBox(height: 10), TextField(controller: _contactName, decoration: InputDecoration(labelText: t('Contact name', 'اسم جهة الاتصال'), prefixIcon: const Icon(Icons.person_outline_rounded))),
        const SizedBox(height: 10), TextField(controller: _contactPhone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t('Contact phone', 'رقم التليفون'), prefixIcon: const Icon(Icons.phone_outlined))),
        const SizedBox(height: 10), TextField(controller: _notes, minLines: 3, maxLines: 6, decoration: InputDecoration(labelText: t('Notes', 'ملاحظات'), prefixIcon: const Icon(Icons.notes_rounded))),
        const SizedBox(height: 14),
        DropdownButtonFormField<AppointmentRecurrence>(initialValue: _recurrence, decoration: InputDecoration(labelText: t('Recurrence', 'التكرار')), items: AppointmentRecurrence.values.map((v) => DropdownMenuItem(value: v, child: Text(_recurrenceLabel(v)))).toList(), onChanged: (v) => setState(() => _recurrence = v ?? AppointmentRecurrence.none)),
        const SizedBox(height: 10),
        DropdownButtonFormField<AppointmentReminder>(initialValue: _reminder, decoration: InputDecoration(labelText: t('Reminder', 'التذكير')), items: AppointmentReminder.values.map((v) => DropdownMenuItem(value: v, child: Text(_reminderLabel(v)))).toList(), onChanged: (v) => setState(() => _reminder = v ?? AppointmentReminder.none)),
        if (doctor) ...[
          const SizedBox(height: 20), Text(t('Doctor appointment', 'موعد طبيب'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10), TextField(controller: _doctorName, decoration: InputDecoration(labelText: t('Doctor name *', 'اسم الدكتور *'), prefixIcon: const Icon(Icons.medical_services_outlined))), const SizedBox(height: 10), TextField(controller: _specialty, decoration: InputDecoration(labelText: t('Specialty', 'التخصص'), prefixIcon: const Icon(Icons.local_hospital_outlined))), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => _pickDateTime(initial: _followUpAt ?? _startsAt.add(const Duration(days: 7)), first: _startsAt, onPicked: (v) => setState(() => _followUpAt = v)), icon: const Icon(Icons.event_repeat_rounded), label: Text(_followUpAt == null ? t('Add follow-up reminder', 'إضافة متابعة') : '${t('Follow-up', 'المتابعة')}: ${_followUpAt!.day}/${_followUpAt!.month}/${_followUpAt!.year}')),
          if (_followUpAt != null) TextButton(onPressed: () => setState(() => _followUpAt = null), child: Text(t('Clear follow-up', 'مسح المتابعة'))),
        ],
        const SizedBox(height: 24), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t('Save appointment', 'حفظ الموعد'), style: const TextStyle(fontWeight: FontWeight.w900)))),
      ]),
    );
  }

  String _typeLabel(AppointmentType v) => switch (v) { AppointmentType.personal => t('Personal', 'شخصي'), AppointmentType.doctor => t('Doctor', 'طبيب'), AppointmentType.work => t('Work', 'عمل'), AppointmentType.government => t('Government', 'حكومي'), AppointmentType.study => t('Study', 'دراسة'), AppointmentType.family => t('Family', 'عائلة'), AppointmentType.travel => t('Travel', 'سفر'), AppointmentType.phoneCall => t('Phone call', 'مكالمة'), AppointmentType.custom => t('Custom', 'مخصص') };
  String _recurrenceLabel(AppointmentRecurrence v) => switch (v) { AppointmentRecurrence.none => t('Does not repeat', 'بدون تكرار'), AppointmentRecurrence.daily => t('Daily', 'يومي'), AppointmentRecurrence.weekly => t('Weekly', 'أسبوعي') };
  String _reminderLabel(AppointmentReminder v) => switch (v) { AppointmentReminder.none => t('No reminder', 'بدون تذكير'), AppointmentReminder.atTime => t('At appointment time', 'وقت الموعد'), AppointmentReminder.fiveMinutesBefore => t('5 minutes before', 'قبلها بـ 5 دقائق'), AppointmentReminder.fifteenMinutesBefore => t('15 minutes before', 'قبلها بـ 15 دقيقة'), AppointmentReminder.thirtyMinutesBefore => t('30 minutes before', 'قبلها بـ 30 دقيقة'), AppointmentReminder.oneHourBefore => t('1 hour before', 'قبلها بساعة'), AppointmentReminder.oneDayBefore => t('1 day before', 'قبلها بيوم') };
}
