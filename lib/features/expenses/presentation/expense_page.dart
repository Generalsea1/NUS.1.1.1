import 'package:flutter/material.dart';

import '../application/expense_lifecycle_service.dart';
import '../domain/expense.dart';
import '../domain/expense_date.dart';
import '../domain/money.dart';

const int _minorUnitScale = 2;

int parseExpenseAmountToMinorUnits(String input) {
  final value = input.trim();
  final match = RegExp(r'^(?:0|[1-9]\d*)(?:\.(\d{1,2}))?$').firstMatch(value);
  if (match == null) {
    throw const FormatException('Enter a valid positive amount with up to 2 decimal places.');
  }

  final integerPart = value.split('.').first;
  final fractionPart = match.group(1) ?? '';
  final paddedFraction = fractionPart.padRight(_minorUnitScale, '0');
  final minorUnits = BigInt.parse(integerPart) * BigInt.from(100) +
      BigInt.parse(paddedFraction.isEmpty ? '0' : paddedFraction);
  final maxInt = BigInt.from(0x7fffffffffffffff);
  if (minorUnits <= BigInt.zero || minorUnits > maxInt) {
    throw const FormatException('Amount is outside the supported range.');
  }
  return minorUnits.toInt();
}

String formatExpenseAmount(Money money) {
  final absolute = money.minorUnits.abs();
  final whole = absolute ~/ 100;
  final minor = (absolute % 100).toString().padLeft(2, '0');
  final sign = money.minorUnits < 0 ? '-' : '';
  return '$sign$whole.$minor';
}

class ExpensePage extends StatefulWidget {
  const ExpensePage({
    super.key,
    required this.service,
    this.isArabic = true,
  });

  final ExpenseLifecycleService service;
  final bool isArabic;

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  bool _loading = true;
  bool _busy = false;
  Object? _error;
  List<Expense> _expenses = const <Expense>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExpensePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service || oldWidget.isArabic != widget.isArabic) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final expenses = await widget.service.list();
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = Object();
      });
    }
  }

  Future<void> _openForm([Expense? expense]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormPage(
          service: widget.service,
          isArabic: widget.isArabic,
          expense: expense,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    await _load();
  }

  Future<void> _deleteExpense(Expense expense) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.isArabic ? 'حذف المصروف؟' : 'Delete expense?'),
        content: Text(widget.isArabic
            ? 'المصروف ده هيتحذف نهائيًا من القائمة.'
            : 'This expense will be removed from the list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(widget.isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    try {
      await widget.service.deleteById(expense.id);
      if (!mounted) return;
      setState(() => _busy = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isArabic ? 'اتحذف بنجاح.' : 'Expense deleted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isArabic
            ? 'حصلت مشكلة في الحذف. جرّب تاني.'
            : 'Could not delete the expense. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isArabic ? 'المصروفات' : 'Expenses'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.isArabic ? 'إضافة مصروف' : 'Add expense'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: widget.isArabic ? 'مش قادرين نحمّل المصروفات' : 'Could not load expenses',
        actionLabel: widget.isArabic ? 'إعادة المحاولة' : 'Retry',
        onAction: _load,
      );
    }
    if (_expenses.isEmpty) {
      return _StateMessage(
        icon: Icons.receipt_long_outlined,
        title: widget.isArabic ? 'لسه مفيش مصروفات' : 'No expenses yet',
        subtitle: widget.isArabic
            ? 'سجّل أول مصروف علشان يظهر هنا.'
            : 'Add your first expense to see it here.',
        actionLabel: widget.isArabic ? 'سجّل أول مصروف' : 'Add your first expense',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onTap: _busy ? null : () => _openForm(expense),
              leading: CircleAvatar(
                child: Text(expense.amount.currencyCode.substring(0, 1)),
              ),
              title: Text(
                '${formatExpenseAmount(expense.amount)} ${expense.amount.currencyCode}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              subtitle: Text(_subtitle(expense)),
              trailing: PopupMenuButton<String>(
                enabled: !_busy,
                onSelected: (value) {
                  if (value == 'edit') _openForm(expense);
                  if (value == 'delete') _deleteExpense(expense);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(widget.isArabic ? 'تعديل' : 'Edit')),
                  PopupMenuItem(value: 'delete', child: Text(widget.isArabic ? 'حذف' : 'Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _subtitle(Expense expense) {
    final parts = <String>[];
    parts.add(expense.date.toIsoString());
    if (expense.category != null) parts.add(expense.category!);
    if (expense.merchant != null) parts.add(expense.merchant!);
    return parts.join(' • ');
  }
}

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({
    super.key,
    required this.service,
    required this.isArabic,
    this.expense,
  });

  final ExpenseLifecycleService service;
  final bool isArabic;
  final Expense? expense;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _categoryController;
  late final TextEditingController _merchantController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _paymentMethodController;
  late ExpenseDate _date;
  bool _saving = false;
  String? _formError;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amountController = TextEditingController(
      text: expense == null ? '' : formatExpenseAmount(expense.amount),
    );
    _currencyController = TextEditingController(
      text: expense?.amount.currencyCode ?? 'USD',
    );
    _categoryController = TextEditingController(text: expense?.category ?? '');
    _merchantController = TextEditingController(text: expense?.merchant ?? '');
    _descriptionController = TextEditingController(text: expense?.description ?? '');
    _paymentMethodController = TextEditingController(text: expense?.paymentMethod ?? '');
    _date = expense?.date ?? _today();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    _categoryController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    _paymentMethodController.dispose();
    super.dispose();
  }

  ExpenseDate _today() {
    final now = DateTime.now();
    return ExpenseDate(year: now.year, month: now.month, day: now.day);
  }

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(1, 1, 1),
      lastDate: DateTime(9999, 12, 31),
      helpText: _t('Expense date', 'تاريخ المصروف'),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _date = ExpenseDate(
        year: selected.year,
        month: selected.month,
        day: selected.day,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _formError = null);

    try {
      final minorUnits = parseExpenseAmountToMinorUnits(_amountController.text);
      final currency = _currencyController.text.trim().toUpperCase();
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
        throw const FormatException('Currency must be exactly three letters.');
      }

      final expense = Expense(
        id: widget.expense?.id ?? 'expense-${DateTime.now().microsecondsSinceEpoch}',
        amount: Money(minorUnits: minorUnits, currencyCode: currency),
        date: _date,
        category: _clean(_categoryController.text),
        merchant: _clean(_merchantController.text),
        description: _clean(_descriptionController.text),
        paymentMethod: _clean(_paymentMethodController.text),
      );

      setState(() => _saving = true);
      if (_editing) {
        await widget.service.update(expense);
      } else {
        await widget.service.create(expense);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _formError = _friendlyValidation(error));
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _formError = _friendlyValidation(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = _t(
        'Could not save the expense. Please try again.',
        'حصلت مشكلة أثناء الحفظ. جرّب تاني.',
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _clean(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _friendlyValidation(Object error) {
    final message = error.toString();
    if (message.contains('Currency') || message.contains('currency')) {
      return _t('Currency must be 3 letters, like USD.', 'العملة لازم تكون 3 حروف، زي USD.');
    }
    if (message.contains('amount') || message.contains('Amount')) {
      return _t(
        'Enter a positive amount with up to 2 decimal places.',
        'اكتب مبلغ أكبر من صفر وبحد أقصى منزلتين عشريتين.',
      );
    }
    return _t('Please check the entered values.', 'راجع البيانات المدخلة.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? _t('Edit expense', 'تعديل مصروف') : _t('New expense', 'مصروف جديد')),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(_saving
                ? _t('Saving…', 'بيتحفظ…')
                : _t('Save expense', 'حفظ المصروف')),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _field(
                controller: _amountController,
                label: _t('Amount', 'المبلغ'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _currencyController,
                label: _t('Currency', 'العملة'),
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_t('Date', 'التاريخ')),
                subtitle: Text(_date.toIsoString()),
                trailing: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_t('Choose', 'اختار')),
                ),
              ),
              const SizedBox(height: 8),
              _field(controller: _categoryController, label: _t('Category', 'الفئة')),
              const SizedBox(height: 14),
              _field(controller: _merchantController, label: _t('Merchant', 'التاجر')),
              const SizedBox(height: 14),
              _field(
                controller: _descriptionController,
                label: _t('Description', 'ملاحظة'),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _field(controller: _paymentMethodController, label: _t('Payment method', 'طريقة الدفع')),
              if (_formError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_formError!),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
