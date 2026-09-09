import 'package:flutter/material.dart';

import '../domain/nus_quick_add_parser.dart';
import '../domain/nus_voice_input.dart';

class NusQuickAddPage extends StatefulWidget {
  const NusQuickAddPage({super.key, required this.onCreateReminder, this.voiceInput});

  final Future<void> Function(String title, DateTime dateTime) onCreateReminder;
  final NusVoiceInput? voiceInput;

  @override
  State<NusQuickAddPage> createState() => _NusQuickAddPageState();
}

class _NusQuickAddPageState extends State<NusQuickAddPage> {
  final _title = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  bool _saving = false;
  bool _listening = false;
  String? _voiceError;
  bool _scheduleDetected = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _setTime(DateTime value) => setState(() => _dateTime = value);

  void _inOneHour() => _setTime(DateTime.now().add(const Duration(hours: 1)));

  void _tomorrowMorning() {
    final now = DateTime.now();
    _setTime(DateTime(now.year, now.month, now.day + 1, 9));
  }

  void _tomorrowEvening() {
    final now = DateTime.now();
    _setTime(DateTime(now.year, now.month, now.day + 1, 18));
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dateTime,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null || !mounted) return;
    _setTime(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _listen() async {
    final voice = widget.voiceInput;
    if (voice == null || _listening) return;
    setState(() {
      _listening = true;
      _voiceError = null;
    });
    try {
      if (!await voice.isAvailable()) {
        if (mounted) setState(() => _voiceError = 'الإدخال الصوتي غير متاح على الجهاز حاليًا.');
        return;
      }
      final transcript = await voice.listen(localeId: 'ar-EG');
      if (!mounted) return;
      if (transcript == null || transcript.trim().isEmpty) {
        setState(() => _voiceError = 'ماقدرتش ألتقط الكلام. جرّب تاني بصوت أوضح.');
        return;
      }
      setState(() {
        _title.text = transcript.trim();
        _title.selection = TextSelection.collapsed(offset: _title.text.length);
      });
      _applyNaturalSchedule(showFeedback: false);
    } catch (_) {
      if (mounted) setState(() => _voiceError = 'حصلت مشكلة في الإدخال الصوتي. جرّب تاني.');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  void _applyNaturalSchedule({required bool showFeedback}) {
    final raw = _title.text.trim();
    if (raw.isEmpty) return;
    final parsed = NusQuickAddParser.parse(raw);
    setState(() {
      _dateTime = parsed.dateTime;
      _scheduleDetected = parsed.scheduleDetected;
    });
    if (parsed.scheduleDetected && parsed.title != raw) {
      _title.text = parsed.title;
      _title.selection = TextSelection.collapsed(offset: _title.text.length);
    }
    if (showFeedback && parsed.scheduleDetected && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NUS فهم الموعد وحدده تلقائيًا: ${_dateTimeLabel(context)}')),
      );
    }
  }

  Future<void> _save() async {
    final raw = _title.text.trim();
    if (raw.isEmpty) return;
    final parsed = NusQuickAddParser.parse(raw, now: DateTime.now());
    final title = parsed.title;
    final dateTime = _scheduleDetected ? _dateTime : parsed.dateTime;
    if (title.isEmpty || dateTime.isBefore(DateTime.now())) return;
    setState(() => _saving = true);
    try {
      await widget.onCreateReminder(title, dateTime);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateTimeLabel(BuildContext context) =>
      '${MaterialLocalizations.of(context).formatFullDate(_dateTime)} • ${TimeOfDay.fromDateTime(_dateTime).format(context)}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة سريعة', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'اكتب الحاجة بطريقتك، وNUS يحاول يفهم اليوم والساعة تلقائيًا ويجهّز الإشعار.',
              style: TextStyle(fontSize: 17, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _scheduleDetected = false,
              onSubmitted: (_) => _saving ? null : _save(),
              decoration: InputDecoration(
                labelText: 'إيه اللي عايز تفتكره؟',
                hintText: 'مثال: أدفع الكهرباء يوم 15 الساعة 10 صباحًا',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('quick-add-parse'),
                      tooltip: 'فهم الموعد تلقائيًا',
                      onPressed: _saving ? null : () => _applyNaturalSchedule(showFeedback: true),
                      icon: const Icon(Icons.auto_fix_high_rounded),
                    ),
                    if (widget.voiceInput != null)
                      IconButton(
                        key: const Key('quick-add-voice'),
                        tooltip: 'إضافة بالصوت',
                        onPressed: _saving || _listening ? null : _listen,
                        icon: Icon(_listening ? Icons.mic : Icons.mic_none_rounded),
                      ),
                  ],
                ),
              ),
            ),
            if (_scheduleDetected) ...[
              const SizedBox(height: 8),
              Text(
                'NUS فهم الموعد تلقائيًا وسيحفظ التذكير في الوقت المحدد.',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
              ),
            ],
            if (_voiceError != null) ...[
              const SizedBox(height: 8),
              Text(_voiceError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            const Text('وقت سريع', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(avatar: const Icon(Icons.schedule_rounded, size: 18), label: const Text('بعد ساعة'), onPressed: _inOneHour),
                ActionChip(avatar: const Icon(Icons.wb_sunny_outlined, size: 18), label: const Text('بكرة 9 صباحًا'), onPressed: _tomorrowMorning),
                ActionChip(avatar: const Icon(Icons.nightlight_outlined, size: 18), label: const Text('بكرة 6 مساءً'), onPressed: _tomorrowEvening),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.event_rounded)),
                title: const Text('موعد التذكير', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(_dateTimeLabel(context)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDateTime,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey<String>('quick-add-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_task_rounded),
              label: Text(_saving ? 'جاري الحفظ…' : 'حفظ التذكير', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
