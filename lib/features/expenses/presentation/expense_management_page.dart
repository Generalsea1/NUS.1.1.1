import 'package:flutter/material.dart';

import '../../../core/supabase_service.dart';
import '../application/expense_management_service.dart';
import '../domain/currency_registry.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_date.dart';
import '../domain/expense_type.dart';
import '../domain/money.dart';
import '../domain/recurring_expense_definition.dart';

int parseExpenseMinorUnits(String input, String currencyCode) {
  final metadata = CurrencyRegistry.get(currencyCode);
  final value = input.trim();
  if (value.isEmpty || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) {
    throw const FormatException('Invalid amount.');
  }
  final parts = value.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  if (fraction.length > metadata.exponent) {
    throw const FormatException('Too many decimal places.');
  }
  final padded = fraction.padRight(metadata.exponent, '0');
  final result = int.parse(parts[0]) * metadata.scale +
      (padded.isEmpty ? 0 : int.parse(padded));
  if (result <= 0) throw const FormatException('Amount must be greater than zero.');
  return result;
}

String formatExpenseMoney(Money money) {
  final metadata = CurrencyRegistry.get(money.currencyCode);
  if (metadata.exponent == 0) return '${money.minorUnits} ${money.currencyCode}';
  final whole = money.minorUnits ~/ metadata.scale;
  final fraction = (money.minorUnits % metadata.scale)
      .toString()
      .padLeft(metadata.exponent, '0');
  return '$whole.$fraction ${money.currencyCode}';
}

class ExpenseManagementPage extends StatefulWidget {
  const ExpenseManagementPage({
    super.key,
    required this.service,
    this.householdCurrencyCode = 'EGP',
  });

  final ExpenseManagementService service;
  final String householdCurrencyCode;

  @override
  State<ExpenseManagementPage> createState() => _ExpenseManagementPageState();
}

class _ExpenseManagementPageState extends State<ExpenseManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _loading = true;
  String? _error;
  List<Expense> _expenses = const [];
  List<RecurringExpenseDefinition> _recurring = const [];
  late String _currency;
  int _actualTotal = 0;
  int _expectedTotal = 0;
  String _month = '';

  String get _userId => SupabaseService.client?.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _currency = widget.householdCurrencyCode.trim().toUpperCase();
    if (!CurrencyRegistry.isSupported(_currency)) _currency = 'EGP';
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final expenses = await widget.service.listExpenses();
      final recurring = await widget.service.listRecurring();
      final actual = await widget.service.monthlyActualTotal(
        year: now.year,
        month: now.month,
        currencyCode: _currency,
      );
      final expected = await widget.service.monthlyExpectedRecurringTotal(
        year: now.year,
        month: now.month,
        currencyCode: _currency,
      );
      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _recurring = recurring;
        _actualTotal = actual;
        _expectedTotal = expected;
        _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل بيانات المصروفات. جرّب إعادة المحاولة.';
        });
      }
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openExpense([Expense? expense]) async {
    if (_userId.isEmpty) {
      _message('لازم تكون مسجل دخول الأول.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        service: widget.service,
        userId: _userId,
        defaultCurrency: _currency,
        definitions: _recurring,
        initial: expense,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _openRecurring([RecurringExpenseDefinition? definition]) async {
    if (_userId.isEmpty) {
      _message('لازم تكون مسجل دخول الأول.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => RecurringFormDialog(
        service: widget.service,
        userId: _userId,
        defaultCurrency: _currency,
        initial: definition,
      ),
    );
    if (ok == true) await _load();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final yes = await _confirm('حذف المصروف؟', 'هيتحذف السجل الفعلي ده فقط.');
    if (yes != true) return;
    try {
      await widget.service.deleteExpense(expense.id);
      await _load();
    } catch (_) {
      _message('تعذر الحذف. جرّب تاني.');
    }
  }

  Future<void> _deleteRecurring(RecurringExpenseDefinition definition) async {
    final yes = await _confirm(
      'حذف المصروف المتكرر؟',
      'الحذف لا يحذف المصروفات الفعلية القديمة.',
    );
    if (yes != true) return;
    try {
      await widget.service.deleteRecurring(definition.id);
      await _load();
    } catch (_) {
      _message('تعذر الحذف.');
    }
  }

  Future<void> _toggleRecurring(RecurringExpenseDefinition definition) async {
    try {
      await widget.service.setRecurringEnabled(
        _userId,
        definition.id,
        !definition.enabled,
      );
      await _load();
    } catch (_) {
      _message('تعذر تغيير حالة المصروف المتكرر.');
    }
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final actualTab = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مصروفات مدير المنزل',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الفعلية'),
            Tab(text: 'المتكررة'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : (actualTab ? () => _openExpense() : () => _openRecurring()),
        icon: const Icon(Icons.add_rounded),
        label: Text(actualTab ? 'إضافة مصروف' : 'إضافة متكرر'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _actualView(),
                    _recurringView(),
                  ],
                ),
    );
  }

  Widget _actualView() => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SummaryCard(
              month: _month,
              actual: _actualTotal,
              expected: _expectedTotal,
              currency: _currency,
            ),
            const SizedBox(height: 16),
            if (_expenses.isEmpty)
              const EmptyState(text: 'لسه مفيش مصروفات فعلية مسجلة.')
            else
              for (final expense in _expenses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        formatExpenseMoney(expense.amount),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${expense.date.toIsoString()} • '
                        '${ExpenseCategories.labelsAr[expense.categoryCode] ?? 'أخرى'} • '
                        '${expense.expenseType.code}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => value == 'edit'
                            ? _openExpense(expense)
                            : _deleteExpense(expense),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );

  Widget _recurringView() => RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'المتكرر هنا توقع فقط. تعريف متكرر لا ينشئ مصروفًا فعليًا تلقائيًا.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_recurring.isEmpty)
              const EmptyState(text: 'لسه مفيش مصروفات متكررة.')
            else
              for (final definition in _recurring)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        definition.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${formatExpenseMoney(definition.amount)} • '
                        '${_frequencyLabel(definition.frequency)} • '
                        '${definition.enabled ? 'مفعّل' : 'موقوف'}',
                      ),
                      leading: Switch(
                        value: definition.enabled,
                        onChanged: (_) => _toggleRecurring(definition),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => value == 'edit'
                            ? _openRecurring(definition)
                            : _deleteRecurring(definition),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );

  String _frequencyLabel(String value) => switch (value) {
        'monthly' => 'شهري',
        'weekly' => 'أسبوعي',
        'biweekly' => 'كل أسبوعين',
        'quarterly' => 'ربع سنوي',
        'yearly' => 'سنوي',
        _ => value,
      };
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.month,
    required this.actual,
    required this.expected,
    required this.currency,
  });
  final String month;
  final int actual;
  final int expected;
  final String currency;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص $month',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      title: 'فعلي',
                      value: formatExpenseMoney(
                        Money(minorUnits: actual, currencyCode: currency),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Metric(
                      title: 'متوقع متكرر',
                      value: formatExpenseMoney(
                        Money(minorUnits: expected, currencyCode: currency),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('العملة: $currency — الفعلي والمتوقع منفصلين عمدًا.'),
            ],
          ),
        ),
      );
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.service,
    required this.userId,
    required this.defaultCurrency,
    required this.definitions,
    this.initial,
  });
  final ExpenseManagementService service;
  final String userId;
  final String defaultCurrency;
  final List<RecurringExpenseDefinition> definitions;
  final Expense? initial;
  @override State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _currency;
  late final TextEditingController _merchant;
  late final TextEditingController _description;
  late ExpenseDate _date;
  late String _category;
  late ExpenseType _type;
  String? _recurringId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _amount = TextEditingController(text: initial == null ? '' : _asInput(initial.amount));
    _currency = TextEditingController(text: initial?.amount.currencyCode ?? widget.defaultCurrency);
    _merchant = TextEditingController(text: initial?.merchant ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _date = initial?.date ?? _today();
    _category = initial?.categoryCode ?? 'food';
    _type = initial?.expenseType ?? ExpenseType.oneTime;
    _recurringId = initial?.recurringDefinitionId;
  }

  ExpenseDate _today() { final n = DateTime.now(); return ExpenseDate(year:n.year,month:n.month,day:n.day); }
  String _asInput(Money money) { final meta=CurrencyRegistry.get(money.currencyCode); if(meta.exponent==0)return '${money.minorUnits}'; return '${money.minorUnits~/meta.scale}.${(money.minorUnits%meta.scale).toString().padLeft(meta.exponent,'0')}'; }
  @override void dispose(){_amount.dispose();_currency.dispose();_merchant.dispose();_description.dispose();super.dispose();}

  Future<void> _save() async {
    try {
      final currency = _currency.text.trim().toUpperCase();
      if (_type == ExpenseType.recurring && _recurringId == null) {
        throw const FormatException('Select a recurring definition.');
      }
      final expense = Expense(
        id: widget.initial?.id ?? 'expense-${DateTime.now().microsecondsSinceEpoch}',
        userId: widget.userId,
        amount: Money(minorUnits: parseExpenseMinorUnits(_amount.text, currency), currencyCode: currency),
        date: _date,
        categoryCode: _category,
        expenseType: _type,
        recurringDefinitionId: _type == ExpenseType.recurring ? _recurringId : null,
        merchant: _merchant.text,
        description: _description.text,
        createdAt: widget.initial?.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      if (widget.initial == null) { await widget.service.createExpense(expense); } else { await widget.service.updateExpense(expense); }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('FormatException: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'مصروف فعلي جديد' : 'تعديل مصروف فعلي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ')),
              TextField(controller: _currency, textCapitalization: TextCapitalization.characters, maxLength: 3, decoration: const InputDecoration(labelText: 'العملة')),
              DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'الفئة'), items: [for (final code in ExpenseCategories.codes) DropdownMenuItem(value: code, child: Text(ExpenseCategories.labelsAr[code]!))], onChanged: (v) { if(v!=null)setState(()=>_category=v); }),
              DropdownButtonFormField<ExpenseType>(initialValue: _type, decoration: const InputDecoration(labelText: 'نوع المصروف'), items: const [DropdownMenuItem(value: ExpenseType.oneTime, child: Text('مرة واحدة')), DropdownMenuItem(value: ExpenseType.variable, child: Text('متغير')), DropdownMenuItem(value: ExpenseType.recurring, child: Text('متكرر فعلي'))], onChanged: (v) { if(v!=null)setState(()=>_type=v); }),
              if (_type == ExpenseType.recurring)
                DropdownButtonFormField<String>(initialValue: _recurringId, decoration: const InputDecoration(labelText: 'تعريف المتكرر'), items: [for (final d in widget.definitions) DropdownMenuItem(value: d.id, child: Text(d.name))], onChanged: (v)=>setState(()=>_recurringId=v)),
              ListTile(contentPadding: EdgeInsets.zero, title: const Text('التاريخ'), subtitle: Text(_date.toIsoString()), trailing: TextButton(onPressed: () async { final s=await showDatePicker(context:context,initialDate:DateTime(_date.year,_date.month,_date.day),firstDate:DateTime(2000),lastDate:DateTime(9999)); if(s!=null&&mounted)setState(()=>_date=ExpenseDate(year:s.year,month:s.month,day:s.day)); }, child: const Text('اختار')),
              TextField(controller: _merchant, decoration: const InputDecoration(labelText: 'التاجر (اختياري)')),
              TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف (اختياري)')),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ),
        actions: [TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:_save,child:const Text('حفظ'))],
      );
}

class RecurringFormDialog extends StatefulWidget {
  const RecurringFormDialog({super.key, required this.service, required this.userId, required this.defaultCurrency, this.initial});
  final ExpenseManagementService service; final String userId; final String defaultCurrency; final RecurringExpenseDefinition? initial;
  @override State<RecurringFormDialog> createState()=>_RecurringFormDialogState();
}
class _RecurringFormDialogState extends State<RecurringFormDialog> {
  late final TextEditingController _name; late final TextEditingController _amount; late final TextEditingController _currency;
  late String _category; late String _frequency; late bool _enabled; late ExpenseDate _start; late ExpenseDate? _end; String? _error;
  @override void initState(){super.initState();final d=widget.initial;_name=TextEditingController(text:d?.name??'');_amount=TextEditingController(text:d==null?'':_asInput(d.amount));_currency=TextEditingController(text:d?.amount.currencyCode??widget.defaultCurrency);_category=d?.categoryCode??'subscriptions';_frequency=d?.frequency??'monthly';_enabled=d?.enabled??true;_start=d?.startDate??_today();_end=d?.endDate;}
  ExpenseDate _today(){final n=DateTime.now();return ExpenseDate(year:n.year,month:n.month,day:n.day);} String _asInput(Money m){final meta=CurrencyRegistry.get(m.currencyCode);if(meta.exponent==0)return '${m.minorUnits}';return '${m.minorUnits~/meta.scale}.${(m.minorUnits%meta.scale).toString().padLeft(meta.exponent,'0')}';}
  @override void dispose(){_name.dispose();_amount.dispose();_currency.dispose();super.dispose();}
  Future<void> _save() async {try{final currency=_currency.text.trim().toUpperCase();final d=RecurringExpenseDefinition(id:widget.initial?.id??'recurring-${DateTime.now().microsecondsSinceEpoch}',userId:widget.userId,name:_name.text,amount:Money(minorUnits:parseExpenseMinorUnits(_amount.text,currency),currencyCode:currency),categoryCode:_category,frequency:_frequency,enabled:_enabled,startDate:_start,endDate:_end,createdAt:widget.initial?.createdAt,updatedAt:DateTime.now().toUtc());if(widget.initial==null){await widget.service.createRecurring(d);}else{await widget.service.updateRecurring(d);}if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('FormatException: ',''));}}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'تعريف مصروف متكرر':'تعديل مصروف متكرر'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:_name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:_amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ')),TextField(controller:_currency,textCapitalization:TextCapitalization.characters,maxLength:3,decoration:const InputDecoration(labelText:'العملة')),DropdownButtonFormField<String>(initialValue:_category,decoration:const InputDecoration(labelText:'الفئة'),items:[for(final code in ExpenseCategories.codes)DropdownMenuItem(value:code,child:Text(ExpenseCategories.labelsAr[code]!))],onChanged:(v){if(v!=null)setState(()=>_category=v);}),DropdownButtonFormField<String>(initialValue:_frequency,decoration:const InputDecoration(labelText:'التكرار'),items:const[DropdownMenuItem(value:'monthly',child:Text('شهري')),DropdownMenuItem(value:'weekly',child:Text('أسبوعي')),DropdownMenuItem(value:'biweekly',child:Text('كل أسبوعين')),DropdownMenuItem(value:'quarterly',child:Text('ربع سنوي')),DropdownMenuItem(value:'yearly',child:Text('سنوي'))],onChanged:(v){if(v!=null)setState(()=>_frequency=v);}),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('مفعّل'),value:_enabled,onChanged:(v)=>setState(()=>_enabled=v)),ListTile(contentPadding:EdgeInsets.zero,title:const Text('يبدأ من'),subtitle:Text(_start.toIsoString()),trailing:TextButton(onPressed:()async{final s=await showDatePicker(context:context,initialDate:DateTime(_start.year,_start.month,_start.day),firstDate:DateTime(2000),lastDate:DateTime(9999));if(s!=null&&mounted)setState(()=>_start=ExpenseDate(year:s.year,month:s.month,day:s.day));},child:const Text('اختار')),ListTile(contentPadding:EdgeInsets.zero,title:Text(_end==null?'بدون نهاية':'ينتهي ${_end!.toIsoString()}'),trailing:_end==null?TextButton(onPressed:()async{final s=await showDatePicker(context:context,initialDate:DateTime(_start.year,_start.month,_start.day),firstDate:DateTime(2000),lastDate:DateTime(9999));if(s!=null&&mounted)setState(()=>_end=ExpenseDate(year:s.year,month:s.month,day:s.day));},child:const Text('تحديد نهاية')):TextButton(onPressed:()=>setState(()=>_end=null),child:const Text('مسح')),if(_error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:_save,child:const Text('حفظ'))]);
}
