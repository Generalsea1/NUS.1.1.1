import 'package:flutter/material.dart';

import '../../expenses/application/expense_management_service.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_date.dart';
import '../../expenses/domain/expense_type.dart';
import '../../expenses/domain/money.dart';
import '../../shopping/application/shopping_lifecycle_service.dart';
import '../domain/nus_quick_add_intent.dart';
import '../domain/nus_quick_add_parser.dart';
import '../domain/nus_voice_input.dart';

class NusQuickAddPage extends StatefulWidget {
  const NusQuickAddPage({
    super.key,
    required this.onCreateReminder,
    this.voiceInput,
    this.shoppingService,
    this.expenseManagementService,
    this.userId,
    this.defaultCurrency = 'EGP',
  });

  final Future<void> Function(String title, DateTime dateTime) onCreateReminder;
  final NusVoiceInput? voiceInput;
  final ShoppingLifecycleService? shoppingService;
  final ExpenseManagementService? expenseManagementService;
  final String? userId;
  final String defaultCurrency;

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
  bool _timeWasExplicitlySelected = false;
  NusQuickAddIntent? _intent;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _setTime(DateTime value, {bool explicit = true}) {
    setState(() {
      _dateTime = value;
      _timeWasExplicitlySelected = explicit;
    });
  }

  void _refreshIntent() {
    final raw = _title.text.trim();
    setState(() {
      _intent = raw.isEmpty
          ? null
          : NusQuickAddIntentClassifier.classify(
              raw,
              defaultCurrency: widget.defaultCurrency,
            );
      _scheduleDetected = false;
    });
  }

  void _inOneHour() => _setTime(DateTime.now().add(const Duration(hours: 1)));

  void _tomorrowMorning() => _setTime(_tomorrowAt(9));

  void _tomorrowEvening() => _setTime(_tomorrowAt(18));

  DateTime _tomorrowAt(int hour) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, hour);
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
      _refreshIntent();
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
      _timeWasExplicitlySelected = parsed.scheduleDetected;
      _intent = NusQuickAddIntentClassifier.classify(
        parsed.title,
        defaultCurrency: widget.defaultCurrency,
      );
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
    if (raw.isEmpty || _saving) return;
    final intent = NusQuickAddIntentClassifier.classify(
      raw,
      defaultCurrency: widget.defaultCurrency,
    );

    switch (intent.kind) {
      case NusQuickAddKind.reminder:
        await _saveReminder(raw);
        break;
      case NusQuickAddKind.shopping:
        await _saveShopping(raw);
        break;
      case NusQuickAddKind.expense:
        await _confirmAndSaveExpense(intent, raw);
        break;
    }
  }

  Future<void> _saveReminder(String raw) async {
    final parsed = NusQuickAddParser.parse(raw, now: DateTime.now());
    final title = parsed.title;
    final dateTime = _timeWasExplicitlySelected ? _dateTime : parsed.dateTime;
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

  Future<void> _saveShopping(String raw) async {
    final service = widget.shoppingService;
    if (service == null) {
      _showMessage('المشتريات غير متاحة في الإعداد الحالي.');
      return;
    }
    final items = _extractShoppingItems(raw);
    if (items.isEmpty) {
      _showMessage('محتاج أعرف اسم المشتريات الأول.');
      return;
    }

    setState(() => _saving = true);
    try {
      final lists = await service.getAllLists();
      const listName = 'مشتريات';
      final existing = lists.where((list) => list.name.trim() == listName).toList();
      final list = existing.isNotEmpty
          ? existing.first
          : await service.createList(name: listName);
      for (final item in items) {
        await service.addItem(list.id, name: item);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _showMessage('حصلت مشكلة أثناء إضافة المشتريات. العملية لم تُعتبر ناجحة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndSaveExpense(NusQuickAddIntent intent, String raw) async {
    final service = widget.expenseManagementService;
    final userId = widget.userId?.trim();
    final amount = intent.amountMajorUnits;
    final currency = intent.currencyCode?.trim().toUpperCase();
    final category = intent.expenseCategoryCode;

    if (service == null || userId == null || userId.isEmpty || amount == null || currency == null || category == null) {
      _showMessage('لا يمكن تسجيل المصروف قبل اكتمال بيانات الحساب والمبلغ والتصنيف.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد تسجيل المصروف'),
        content: Text(
          'المبلغ: $amount $currency\n'
          'التصنيف: ${_categoryLabel(category)}\n\n'
          'سيتم تسجيل العملية كمصروف فعلي اليوم. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تأكيد الحفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final expense = Expense(
        id: 'quick-add-${now.microsecondsSinceEpoch}',
        userId: userId,
        amount: Money(
          minorUnits: CurrencyRegistry.majorToMinor(amount, currency),
          currencyCode: currency,
        ),
        date: ExpenseDate(year: now.year, month: now.month, day: now.day),
        categoryCode: category,
        expenseType: ExpenseType.oneTime,
        description: raw,
      );
      await service.createExpense(expense);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _showMessage('تعذر تسجيل المصروف. لم يتم اعتبار العملية ناجحة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _extractShoppingItems(String raw) {
    var text = raw.trim();
    const prefixes = <String>[
      'قائمة المشتريات',
      'قائمه المشتريات',
      'مشتريات',
      'هات ',
      'هات',
      'جيب ',
      'جيب',
      'اشتري ',
      'اشتري',
      'اشترى ',
      'اشترى',
      'عايز اجيب ',
      'عايز أجيب ',
      'عايز اجيب',
      'عايز أجيب',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        break;
      }
    }
    text = text
        .replaceAll('قائمة المشتريات', '')
        .replaceAll('قائمه المشتريات', '')
        .trim();
    return text
        .replaceAll('،', ',')
        .split(RegExp(r'\s+و\s+|,|\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _categoryLabel(String code) {
    switch (code) {
      case 'utilities':
        return 'فواتير ومرافق';
      case 'food':
        return 'طعام';
      case 'transportation':
        return 'مواصلات';
      case 'healthcare':
        return 'صحة';
      case 'education':
        return 'تعليم';
      case 'housing':
        return 'سكن';
      case 'subscriptions':
        return 'اشتراكات';
      case 'maintenance':
        return 'صيانة';
      case 'debt':
        return 'ديون وسداد';
      default:
        return 'أخرى';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateTimeLabel(BuildContext context) =>
      '${MaterialLocalizations.of(context).formatFullDate(_dateTime)} • ${TimeOfDay.fromDateTime(_dateTime).format(context)}';

  String _intentLabel(NusQuickAddIntent intent) {
    switch (intent.kind) {
      case NusQuickAddKind.reminder:
        return 'تذكير / مهمة';
      case NusQuickAddKind.shopping:
        return 'مشتريات';
      case NusQuickAddKind.expense:
        return 'مصروف';
    }
  }

  IconData _intentIcon(NusQuickAddKind kind) {
    switch (kind) {
      case NusQuickAddKind.reminder:
        return Icons.check_circle_outline_rounded;
      case NusQuickAddKind.shopping:
        return Icons.shopping_cart_outlined;
      case NusQuickAddKind.expense:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final intent = _intent;
    final isReminder = intent == null || intent.kind == NusQuickAddKind.reminder;
    final actionLabel = switch (intent?.kind) {
      NusQuickAddKind.shopping => 'إضافة للمشتريات',
      NusQuickAddKind.expense => 'تسجيل المصروف',
      _ => 'حفظ التذكير',
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة سريعة', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'اكتب الحاجة بطريقتك، وNUS يحاول يفهم نوع الطلب واليوم والساعة قبل أي تنفيذ.',
              style: TextStyle(fontSize: 17, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _refreshIntent(),
              onSubmitted: (_) => _saving ? null : _save(),
              decoration: InputDecoration(
                labelText: 'إيه اللي عايز NUS يعمله؟',
                hintText: 'مثال: أدفع الكهرباء يوم 15 الساعة 10 صباحًا',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('quick-add-parse'),
                      tooltip: 'فهم الطلب والموعد',
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
            if (intent != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_intentIcon(intent.kind))),
                  title: Text('NUS فهمها كـ ${_intentLabel(intent)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    intent.kind == NusQuickAddKind.expense && intent.amountMajorUnits != null
                        ? '${intent.amountMajorUnits} ${intent.currencyCode ?? ''} • ثقة ${intent.confidence}%'
                        : 'ثقة ${intent.confidence}%',
                  ),
                ),
              ),
            ],
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
            if (isReminder) ...[
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
            ],
            if (intent?.kind == NusQuickAddKind.shopping) ...[
              const SizedBox(height: 12),
              Text(
                'سيضيف NUS العناصر تلقائيًا إلى قائمة «مشتريات».',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            if (intent?.kind == NusQuickAddKind.expense) ...[
              const SizedBox(height: 12),
              Text(
                'لن يتم تسجيل المصروف إلا بعد أن تؤكد العملية صراحةً.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey<String>('quick-add-save'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(intent?.kind == NusQuickAddKind.shopping
                      ? Icons.shopping_cart_checkout_rounded
                      : intent?.kind == NusQuickAddKind.expense
                          ? Icons.account_balance_wallet_rounded
                          : Icons.add_task_rounded),
              label: Text(_saving ? 'جاري التنفيذ…' : actionLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}
