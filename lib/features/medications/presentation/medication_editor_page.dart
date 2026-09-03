import 'package:flutter/material.dart';

import '../domain/medication.dart';

class MedicationEditorPage extends StatefulWidget {
  const MedicationEditorPage({super.key, this.initial, this.isArabic = true});

  final Medication? initial;
  final bool isArabic;

  @override
  State<MedicationEditorPage> createState() => _MedicationEditorPageState();
}

class _MedicationEditorPageState extends State<MedicationEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _customUnit;
  late final TextEditingController _instructions;
  late final TextEditingController _notes;
  late DateTime _startDate;
  late DateTime? _endDate;
  late bool _isActive;
  late DosageUnit _unit;
  late List<MedicationSchedule> _schedules;

  bool get _editing => widget.initial != null;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final medication = widget.initial;
    _name = TextEditingController(text: medication?.name ?? '');
    _amount = TextEditingController(text: medication?.dosage.amount ?? '');
    _customUnit = TextEditingController(text: medication?.dosage.customUnit ?? '');
    _instructions = TextEditingController(text: medication?.instructions ?? '');
    _notes = TextEditingController(text: medication?.notes ?? '');
    _startDate = medication?.startDate ?? DateUtils.dateOnly(DateTime.now());
    _endDate = medication?.endDate;
    _isActive = medication?.isActive ?? true;
    _unit = medication?.dosage.unit ?? DosageUnit.tablet;
    _schedules = medication == null
        ? <MedicationSchedule>[_newSchedule()]
        : List<MedicationSchedule>.from(medication.schedules);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _customUnit.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  MedicationSchedule _newSchedule() => MedicationSchedule(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        minutesSinceMidnight: 9 * 60,
        frequency: MedicationFrequency.daily,
        reminder: MedicationReminder.atTime,
      );

  Future<void> _pickDate({required bool end}) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final first = end ? _startDate : now;
    final initial = end ? (_endDate ?? _startDate) : _startDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: initial.isBefore(first) ? first : initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      final date = DateUtils.dateOnly(picked);
      if (end) {
        _endDate = date;
      } else {
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
      }
    });
  }

  Future<void> _editSchedule(int index) async {
    final edited = await showModalBottomSheet<MedicationSchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleEditorSheet(
        initial: _schedules[index],
        isArabic: widget.isArabic,
      ),
    );
    if (!mounted || edited == null) return;
    setState(() => _schedules[index] = edited);
  }

  Future<void> _addSchedule() async {
    final schedule = await showModalBottomSheet<MedicationSchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleEditorSheet(
        initial: _newSchedule(),
        isArabic: widget.isArabic,
      ),
    );
    if (!mounted || schedule == null) return;
    setState(() => _schedules.add(schedule));
  }

  void _removeSchedule(int index) => setState(() => _schedules.removeAt(index));

  void _save() {
    final existing = widget.initial;
    final medication = Medication(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      dosage: Dosage(
        amount: _amount.text.trim(),
        unit: _unit,
        customUnit: _unit == DosageUnit.custom ? _clean(_customUnit.text) : null,
      ),
      instructions: _clean(_instructions.text),
      notes: _clean(_notes.text),
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      schedules: List<MedicationSchedule>.from(_schedules),
    );

    final errors = MedicationValidator.validate(medication);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_error(errors.first))));
      return;
    }

    Navigator.of(context).pop(medication);
  }

  String? _clean(String value) => value.trim().isEmpty ? null : value.trim();

  String _error(String value) => switch (value) {
        'name_required' => t('Medication name is required.', 'اسم الدواء مطلوب.'),
        'amount_required' => t('Dosage amount is required.', 'جرعة الدواء مطلوبة.'),
        'custom_unit_required' => t('Enter the custom dosage unit.', 'اكتب وحدة الجرعة المخصصة.'),
        'schedules_required' => t('Add at least one schedule.', 'لازم تضيف ميعاد جرعة واحد على الأقل.'),
        'schedule_time_invalid' => t('Choose a valid schedule time.', 'اختار وقت صحيح للجرعة.'),
        'weekday_required' => t('Choose at least one weekday.', 'اختار يوم واحد على الأقل.'),
        'weekday_invalid' => t('The selected weekdays are invalid.', 'الأيام المختارة غير صحيحة.'),
        'weekday_duplicate' => t('A weekday was selected twice.', 'في يوم متكرر في الاختيارات.'),
        'weekday_not_allowed_for_daily' => t('Daily schedules cannot have selected weekdays.', 'الجدول اليومي لا يحتاج أيام مختارة.'),
        'schedule_id_duplicate' => t('Each schedule must be unique.', 'كل جدول جرعة لازم يكون مميز.'),
        'schedule_duplicate' => t('Duplicate schedules are not allowed.', 'مينفعش تكرر نفس جدول الجرعة.'),
        'end_date_before_start_date' => t('End date must be on or after the start date.', 'تاريخ الانتهاء لازم يكون بعد أو نفس تاريخ البداية.'),
        _ => t('Please review the medication details.', 'راجع بيانات الدواء.'),
      };

  String _unitLabel(DosageUnit unit) => switch (unit) {
        DosageUnit.tablet => t('Tablet', 'قرص'),
        DosageUnit.capsule => t('Capsule', 'كبسولة'),
        DosageUnit.ml => 'ml',
        DosageUnit.drop => t('Drop', 'نقطة'),
        DosageUnit.puff => t('Puff', 'بَخّة'),
        DosageUnit.injection => t('Injection', 'حقنة'),
        DosageUnit.custom => t('Custom', 'مخصص'),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? t('Edit medication', 'تعديل الدواء') : t('Add medication', 'إضافة دواء'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          TextField(
            controller: _name,
            autofocus: !_editing,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: t('Medication name *', 'اسم الدواء *'),
              prefixIcon: const Icon(Icons.medication_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t('Amount *', 'الكمية *'),
                    prefixIcon: const Icon(Icons.straighten_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<DosageUnit>(
                  initialValue: _unit,
                  decoration: InputDecoration(labelText: t('Unit *', 'الوحدة *')),
                  items: DosageUnit.values
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(_unitLabel(unit))))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _unit = value);
                  },
                ),
              ),
            ],
          ),
          if (_unit == DosageUnit.custom) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customUnit,
              decoration: InputDecoration(
                labelText: t('Custom unit *', 'الوحدة المخصصة *'),
                prefixIcon: const Icon(Icons.edit_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _instructions,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: t('Instructions', 'التعليمات'),
              prefixIcon: const Icon(Icons.info_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: t('Notes', 'ملاحظات'),
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(t('Date range', 'الفترة'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(end: false),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(end: true),
                  icon: const Icon(Icons.event_outlined),
                  label: Text(_endDate == null
                      ? t('No end date', 'بدون نهاية')
                      : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                ),
              ),
            ],
          ),
          if (_endDate != null)
            Align(
              alignment: widget.isArabic ? Alignment.centerLeft : Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _endDate = null),
                child: Text(t('Clear end date', 'مسح تاريخ الانتهاء')),
              ),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(t('Medication is active', 'الدواء نشط')),
            subtitle: Text(t('Active medications can schedule reminders.', 'الدواء النشط يمكنه تشغيل التذكيرات.')),
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Schedules', 'مواعيد الجرعات'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              TextButton.icon(onPressed: _addSchedule, icon: const Icon(Icons.add_rounded), label: Text(t('Add', 'إضافة'))),
            ],
          ),
          const SizedBox(height: 8),
          ..._schedules.asMap().entries.map(
                (entry) => _ScheduleCard(
                  schedule: entry.value,
                  isArabic: widget.isArabic,
                  onTap: () => _editSchedule(entry.key),
                  onDelete: () => _removeSchedule(entry.key),
                ),
              ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('medication_editor_save'),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _editing ? t('Save changes', 'حفظ التعديلات') : t('Save medication', 'حفظ الدواء'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.isArabic, required this.onTap, required this.onDelete});

  final MedicationSchedule schedule;
  final bool isArabic;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final hour = schedule.minutesSinceMidnight ~/ 60;
    final minute = schedule.minutesSinceMidnight % 60;
    final time = TimeOfDay(hour: hour, minute: minute).format(context);
    final frequency = schedule.frequency == MedicationFrequency.daily
        ? t('Daily', 'يومي')
        : '${t('Selected weekdays', 'أيام محددة')}: ${_weekdays(schedule.selectedWeekdays)}';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
        title: Text(time, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('$frequency • ${_reminderLabel(schedule.reminder)}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onTap();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(t('Edit', 'تعديل'))),
            PopupMenuItem(value: 'delete', child: Text(t('Delete', 'حذف'))),
          ],
        ),
      ),
    );
  }

  String _weekdays(List<int> days) => days.map((day) => switch (day) {
        1 => t('Mon', 'الاثنين'),
        2 => t('Tue', 'الثلاثاء'),
        3 => t('Wed', 'الأربعاء'),
        4 => t('Thu', 'الخميس'),
        5 => t('Fri', 'الجمعة'),
        6 => t('Sat', 'السبت'),
        7 => t('Sun', 'الأحد'),
        _ => '?',
      }).join(isArabic ? '، ' : ', ');

  String _reminderLabel(MedicationReminder reminder) => switch (reminder) {
        MedicationReminder.none => t('No reminder', 'بدون تذكير'),
        MedicationReminder.atTime => t('At time', 'في الموعد'),
        MedicationReminder.fiveMinutesBefore => t('5 min before', 'قبلها بـ 5 دقايق'),
        MedicationReminder.fifteenMinutesBefore => t('15 min before', 'قبلها بـ 15 دقيقة'),
        MedicationReminder.thirtyMinutesBefore => t('30 min before', 'قبلها بـ 30 دقيقة'),
        MedicationReminder.sixtyMinutesBefore => t('60 min before', 'قبلها بـ 60 دقيقة'),
        MedicationReminder.oneDayBefore => t('1 day before', 'قبلها بيوم'),
      };
}

class _ScheduleEditorSheet extends StatefulWidget {
  const _ScheduleEditorSheet({required this.initial, required this.isArabic});

  final MedicationSchedule initial;
  final bool isArabic;

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late TimeOfDay _time;
  late MedicationFrequency _frequency;
  late Set<int> _weekdays;
  late MedicationReminder _reminder;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final schedule = widget.initial;
    _time = TimeOfDay(hour: schedule.minutesSinceMidnight ~/ 60, minute: schedule.minutesSinceMidnight % 60);
    _frequency = schedule.frequency;
    _weekdays = schedule.selectedWeekdays.toSet();
    _reminder = schedule.reminder;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  void _save() {
    final schedule = widget.initial.copyWith(
      minutesSinceMidnight: _time.hour * 60 + _time.minute,
      frequency: _frequency,
      selectedWeekdays: _frequency == MedicationFrequency.daily ? const <int>[] : _weekdays.toList()..sort(),
      reminder: _reminder,
    );
    final errors = schedule.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_error(errors.first))));
      return;
    }
    Navigator.of(context).pop(schedule);
  }

  String _error(String error) => switch (error) {
        'weekday_required' => t('Choose at least one weekday.', 'اختار يوم واحد على الأقل.'),
        'weekday_invalid' => t('The selected weekdays are invalid.', 'الأيام المختارة غير صحيحة.'),
        'weekday_duplicate' => t('A weekday was selected twice.', 'في يوم متكرر في الاختيارات.'),
        _ => t('Please review the schedule.', 'راجع بيانات ميعاد الجرعة.'),
      };

  String _reminderLabel(MedicationReminder reminder) => switch (reminder) {
        MedicationReminder.none => t('None', 'بدون تذكير'),
        MedicationReminder.atTime => t('At time', 'في الموعد'),
        MedicationReminder.fiveMinutesBefore => t('5 minutes before', 'قبلها بـ 5 دقائق'),
        MedicationReminder.fifteenMinutesBefore => t('15 minutes before', 'قبلها بـ 15 دقيقة'),
        MedicationReminder.thirtyMinutesBefore => t('30 minutes before', 'قبلها بـ 30 دقيقة'),
        MedicationReminder.sixtyMinutesBefore => t('60 minutes before', 'قبلها بـ 60 دقيقة'),
        MedicationReminder.oneDayBefore => t('1 day before', 'قبلها بيوم'),
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(t('Schedule', 'ميعاد الجرعة'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.schedule_outlined), label: Text(_time.format(context))),
            const SizedBox(height: 12),
            DropdownButtonFormField<MedicationFrequency>(
              initialValue: _frequency,
              decoration: InputDecoration(labelText: t('Frequency', 'التكرار')),
              items: [
                DropdownMenuItem(value: MedicationFrequency.daily, child: Text(t('Daily', 'يومي'))),
                DropdownMenuItem(value: MedicationFrequency.selectedWeekdays, child: Text(t('Selected weekdays', 'أيام محددة'))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _frequency = value);
              },
            ),
            if (_frequency == MedicationFrequency.selectedWeekdays) ...[
              const SizedBox(height: 14),
              Text(t('Weekdays *', 'أيام الأسبوع *'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final labels = widget.isArabic
                      ? const ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد']
                      : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return FilterChip(
                    label: Text(labels[index]),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(day);
                      } else {
                        _weekdays.remove(day);
                      }
                    }),
                  );
                }),
              ),
            ],
            const SizedBox(height: 14),
            DropdownButtonFormField<MedicationReminder>(
              initialValue: _reminder,
              decoration: InputDecoration(labelText: t('Reminder', 'التذكير')),
              items: MedicationReminder.values
                  .map((reminder) => DropdownMenuItem(value: reminder, child: Text(_reminderLabel(reminder))))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _reminder = value);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: Text(t('Save schedule', 'حفظ الميعاد'))),
          ],
        ),
      ),
    );
  }
}
