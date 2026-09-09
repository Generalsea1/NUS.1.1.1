import 'package:flutter/material.dart';

class NusQuickAddPage extends StatefulWidget {
  const NusQuickAddPage({super.key, required this.onCreateReminder});

  final Future<void> Function(String title, DateTime dateTime) onCreateReminder;

  @override
  State<NusQuickAddPage> createState() => _NusQuickAddPageState();
}

class _NusQuickAddPageState extends State<NusQuickAddPage> {
  final _title = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _dateTime.isBefore(DateTime.now())) return;
    setState(() => _saving = true);
    try {
      await widget.onCreateReminder(title, _dateTime);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة سريعة', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('فكّر في الحاجة، اكتبها، وحدد وقتها. NUS هيفظ التذكير ويجهّز الإشعار.', style: TextStyle(fontSize: 17, height: 1.5)),
            const SizedBox(height: 18),
            TextField(
              controller: _title,
              autofocus: true,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saving ? null : _save(),
              decoration: const InputDecoration(
                labelText: 'إيه اللي عايز تفتكره؟',
                hintText: 'مثال: أدفع الكهرباء يوم 15',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.schedule_rounded)),
                title: const Text('موعد التذكير', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(MaterialLocalizations.of(context).formatFullDate(_dateTime) + ' • ' + TimeOfDay.fromDateTime(_dateTime).format(context)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickDateTime,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
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
