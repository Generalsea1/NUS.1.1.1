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
  if (value.isEmpty || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value)) throw const FormatException('Invalid amount.');
  final parts = value.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  if (fraction.length > metadata.exponent) throw const FormatException('Too many decimal places.');
  final padded = fraction.padRight(metadata.exponent, '0');
  final minor = int.parse(parts[0]) * metadata.scale + (padded.isEmpty ? 0 : int.parse(padded));
  if (minor <= 0) throw const FormatException('Amount must be greater than zero.');
  return minor;
}

String formatExpenseMoney(Money money) {
  final metadata = CurrencyRegistry.get(money.currencyCode);
  if (metadata.exponent == 0) return '${money.minorUnits} ${money.currencyCode}';
  final whole = money.minorUnits ~/ metadata.scale;
  final fraction = (money.minorUnits % metadata.scale).toString().padLeft(metadata.exponent, '0');
  return '$whole.$fraction ${money.currencyCode}';
}

class ExpenseManagementPage extends StatefulWidget {
  const ExpenseManagementPage({super.key, required this.service, this.householdCurrencyCode = 'EGP'});
  final ExpenseManagementService service;
  final String householdCurrencyCode;
  @override State<ExpenseManagementPage> createState() => _ExpenseManagementPageState();
}

class _ExpenseManagementPageState extends State<ExpenseManagementPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  bool _loading = true;
  String? _error;
  List<Expense> _expenses = const [];
  List<RecurringExpenseDefinition> _recurring = const [];
  int _actualTotal = 0;
  int _expectedTotal = 0;
  late String _currency;
  String _month = '';

  String get _userId => SupabaseService.client?.auth.currentUser?.id ?? '';
  @override void initState() { super.initState(); _currency = widget.householdCurrencyCode.trim().toUpperCase(); if (!CurrencyRegistry.isSupported(_currency)) _currency = 'EGP'; _load(); }
  void _onTabChanged() { if (mounted) setState(() {}); }
  @override void dispose() { _tabs.removeListener(_onTabChanged); _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      _expenses = await widget.service.listExpenses();
      _recurring = await widget.service.listRecurring();
      _actualTotal = await widget.service.monthlyActualTotal(year: now.year, month: now.month, currencyCode: _currency);
      _expectedTotal = await widget.service.monthlyExpectedRecurringTotal(year: now.year, month: now.month, currencyCode: _currency);
      _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل بيانات المصروفات. جرّب إعادة المحاولة.'; });
    }
  }

  Future<void> _createExpense() async {
    if (_userId.isEmpty) { _show('لازم تكون مسجل دخول الأول.'); return; }
    final ok = await showDialog<bool>(context: context, builder: (_) => _ExpenseDialog(service: widget.service, userId: _userId, definitions: _recurring, defaultCurrency: _currency));
    if (ok == true) await _load();
  }
  Future<void> _editExpense(Expense expense) async { final ok = await showDialog<bool>(context: context, builder: (_) => _ExpenseDialog(service: widget.service, userId: _userId, definitions: _recurring, defaultCurrency: _currency, initial: expense)); if (ok == true) await _load(); }
  Future<void> _createRecurring() async { if (_userId.isEmpty) { _show('لازم تكون مسجل دخول الأول.'); return; } final ok = await showDialog<bool>(context: context, builder: (_) => _RecurringDialog(service: widget.service, userId: _userId, defaultCurrency: _currency)); if (ok == true) await _load(); }
  Future<void> _editRecurring(RecurringExpenseDefinition d) async { final ok = await showDialog<bool>(context: context, builder: (_) => _RecurringDialog(service: widget.service, userId: _userId, defaultCurrency: _currency, initial: d)); if (ok == true) await _load(); }
  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  Future<bool?> _confirm(String title, String message) => showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد'))]));
  Future<void> _deleteExpense(Expense e) async { if (await _confirm('حذف المصروف؟', 'هيتحذف السجل الفعلي ده فقط.') != true) return; try { await widget.service.deleteExpense(e.id); await _load(); } catch (_) { _show('تعذر الحذف. جرّب تاني.'); } }
  Future<void> _toggleRecurring(RecurringExpenseDefinition d) async { try { await widget.service.setRecurringEnabled(_userId, d.id, !d.enabled); await _load(); } catch (_) { _show('تعذر تغيير حالة المصروف المتكرر.'); } }
  Future<void> _deleteRecurring(RecurringExpenseDefinition d) async { if (await _confirm('حذف المصروف المتكرر؟', 'الحذف لا يحذف المصروفات الفعلية القديمة.') != true) return; try { await widget.service.deleteRecurring(d.id); await _load(); } catch (_) { _show('تعذر الحذف.'); } }

  @override Widget build(BuildContext context) { final actual = _tabs.index == 0; return Scaffold(appBar: AppBar(title: const Text('مصروفات مدير المنزل', style: TextStyle(fontWeight: FontWeight.w900)), bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'الفعلية'), Tab(text: 'المتكررة')])), floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : (actual ? _createExpense : _createRecurring), icon: const Icon(Icons.add_rounded), label: Text(actual ? 'إضافة مصروف' : 'إضافة متكرر')), body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _ErrorState(message: _error!, onRetry: _load) : TabBarView(controller: _tabs, children: [_actualView(), _recurringView()])); }
  Widget _actualView() => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,96), children: [_SummaryCard(month: _month, actual: _actualTotal, expected: _expectedTotal, currency: _currency), const SizedBox(height: 16), if (_expenses.isEmpty) const _EmptyState(text: 'لسه مفيش مصروفات فعلية مسجلة.') else ..._expenses.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(title: Text(formatExpenseMoney(e.amount), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${e.date.toIsoString()} • ${ExpenseCategories.labelsAr[e.categoryCode] ?? 'أخرى'} • ${e.expenseType.code}'), trailing: PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _editExpense(e) : _deleteExpense(e), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]))))]) );
  Widget _recurringView() => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,96), children: [const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('المتكرر هنا توقع فقط. تعريف متكرر لا ينشئ مصروفًا فعليًا تلقائيًا.'))), const SizedBox(height: 16), if (_recurring.isEmpty) const _EmptyState(text: 'لسه مفيش مصروفات متكررة.') else ..._recurring.map((d) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${formatExpenseMoney(d.amount)} • ${_frequency(d.frequency)} • ${d.enabled ? 'مفعّل' : 'موقوف'}'), leading: Switch(value: d.enabled, onChanged: (_) => _toggleRecurring(d)), trailing: PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _editRecurring(d) : _deleteRecurring(d), itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))]))))]) );
  String _frequency(String v) => switch (v) { 'monthly' => 'شهري', 'weekly' => 'أسبوعي', 'biweekly' => 'كل أسبوعين', 'quarterly' => 'ربع سنوي', 'yearly' => 'سنوي', _ => v };
}

class _SummaryCard extends StatelessWidget { const _SummaryCard({required this.month, required this.actual, required this.expected, required this.currency}); final String month; final int actual; final int expected; final String currency; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ملخص $month', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 12), Row(children: [Expanded(child: _Metric(title: 'فعلي', value: formatExpenseMoney(Money(minorUnits: actual, currencyCode: currency)))), Expanded(child: _Metric(title: 'متوقع متكرر', value: formatExpenseMoney(Money(minorUnits: expected, currencyCode: currency))))]), const SizedBox(height: 8), Text('العملة: $currency — الفعلي والمتوقع منفصلين عمدًا.')])); }
class _Metric extends StatelessWidget { const _Metric({required this.title, required this.value}); final String title; final String value; @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]); }
class _EmptyState extends StatelessWidget { const _EmptyState({required this.text}); final String text; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Text(text, textAlign: TextAlign.center))); }
class _ErrorState extends StatelessWidget { const _ErrorState({required this.message, required this.onRetry}); final String message; final VoidCallback onRetry; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))])))); }

class _ExpenseDialog extends StatefulWidget { const _ExpenseDialog({required this.service, required this.userId, required this.definitions, required this.defaultCurrency, this.initial}); final ExpenseManagementService service; final String userId; final List<RecurringExpenseDefinition> definitions; final String defaultCurrency; final Expense? initial; @override State<_ExpenseDialog> createState() => _ExpenseDialogState(); }
class _ExpenseDialogState extends State<_ExpenseDialog> {
  late final TextEditingController _amount = TextEditingController(text: widget.initial == null ? '' : _asInput(widget.initial!.amount));
  late final TextEditingController _currency = TextEditingController(text: widget.initial?.amount.currencyCode ?? widget.defaultCurrency);
  late final TextEditingController _merchant = TextEditingController(text: widget.initial?.merchant ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.initial?.description ?? '');
  late ExpenseDate _date = widget.initial?.date ?? _today();
  late String _category = widget.initial?.categoryCode ?? 'food';
  late ExpenseType _type = widget.initial?.expenseType ?? ExpenseType.oneTime;
  String? _recurringId = widget.initial?.recurringDefinitionId;
  String? _error;
  ExpenseDate _today() { final n = DateTime.now(); return ExpenseDate(year:n.year,month:n.month,day:n.day); }
  String _asInput(Money m) { final meta = CurrencyRegistry.get(m.currencyCode); if (meta.exponent == 0) return '${m.minorUnits}'; return '${m.minorUnits ~/ meta.scale}.${(m.minorUnits % meta.scale).toString().padLeft(meta.exponent, '0')}'; }
  @override void dispose() { _amount.dispose(); _currency.dispose(); _merchant.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _save() async { try { final currency = _currency.text.trim().toUpperCase(); final type = _type; final recurring = type == ExpenseType.recurring ? _recurringId : null; if (type == ExpenseType.recurring && recurring == null) throw const FormatException('Select a recurring definition.'); final expense = Expense(id: widget.initial?.id ?? 'expense-${DateTime.now().microsecondsSinceEpoch}', userId: widget.userId, amount: Money(minorUnits: parseExpenseMinorUnits(_amount.text, currency), currencyCode: currency), date: _date, categoryCode: _category, expenseType: type, recurringDefinitionId: recurring, merchant: _merchant.text, description: _description.text, createdAt: widget.initial?.createdAt, updatedAt: DateTime.now().toUtc()); if (widget.initial == null) await widget.service.createExpense(expense); else await widget.service.updateExpense(expense); if (mounted) Navigator.pop(context, true); } catch (e) { if (mounted) setState(() => _error = e.toString().replaceFirst('FormatException: ', '').replaceFirst('Invalid argument(s): ', '')); } }
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.initial == null ? 'مصروف فعلي جديد' : 'تعديل مصروف فعلي'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller:_amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ')),TextField(controller:_currency,textCapitalization:TextCapitalization.characters,maxLength:3,decoration:const InputDecoration(labelText:'العملة')),DropdownButtonFormField<String>(value:_category,decoration:const InputDecoration(labelText:'الفئة'),items:[for(final code in ExpenseCategories.codes) DropdownMenuItem(value:code,child:Text(ExpenseCategories.labelsAr[code]!))],onChanged:(v){if(v!=null)setState(()=>_category=v);}),DropdownButtonFormField<ExpenseType>(value:_type,decoration:const InputDecoration(labelText:'نوع المصروف'),items:const [DropdownMenuItem(value:ExpenseType.oneTime,child:Text('مرة واحدة')),DropdownMenuItem(value:ExpenseType.variable,child:Text('متغير')),DropdownMenuItem(value:ExpenseType.recurring,child:Text('متكرر فعلي'))],onChanged:(v){if(v!=null)setState(()=>_type=v);}),if(_type==ExpenseType.recurring)DropdownButtonFormField<String>(value:_recurringId,decoration:const InputDecoration(labelText:'تعريف المتكرر'),items:[for(final d in widget.definitions) DropdownMenuItem(value:d.id,child:Text(d.name))],onChanged:(v)=>setState(()=>_recurringId=v)),ListTile(contentPadding:EdgeInsets.zero,title:const Text('التاريخ'),subtitle:Text('${_date.toIsoString()}'),trailing:TextButton(onPressed:()async{final s=await showDatePicker(context:context,initialDate:DateTime(_date.year,_date.month,_date.day),firstDate:DateTime(2000),lastDate:DateTime(9999));if(s!=null&&mounted)setState(()=>_date=ExpenseDate(year:s.year,month:s.month,day:s.day));},child:const Text('اختار')),TextField(controller:_merchant,decoration:const InputDecoration(labelText:'التاجر (اختياري)')),TextField(controller:_description,decoration:const InputDecoration(labelText:'وصف (اختياري)'),maxLines:2),if(_error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:_save,child:const Text('حفظ'))]);
}

class _RecurringDialog extends StatefulWidget { const _RecurringDialog({required this.service, required this.userId, required this.defaultCurrency, this.initial}); final ExpenseManagementService service; final String userId; final String defaultCurrency; final RecurringExpenseDefinition? initial; @override State<_RecurringDialog> createState()=>_RecurringDialogState(); }
class _RecurringDialogState extends State<_RecurringDialog> {
  late final TextEditingController _name=TextEditingController(text:widget.initial?.name??'');
  late final TextEditingController _amount=TextEditingController(text:widget.initial==null?'':_asInput(widget.initial!.amount));
  late final TextEditingController _currency=TextEditingController(text:widget.initial?.amount.currencyCode??widget.defaultCurrency);
  late String _category=widget.initial?.categoryCode??'subscriptions';
  late String _frequency=widget.initial?.frequency??'monthly';
  late bool _enabled=widget.initial?.enabled??true;
  late ExpenseDate _start=widget.initial?.startDate??_today();
  late ExpenseDate? _end=widget.initial?.endDate;
  String? _error;
  ExpenseDate _today(){final n=DateTime.now();return ExpenseDate(year:n.year,month:n.month,day:n.day);}
  String _asInput(Money m){final meta=CurrencyRegistry.get(m.currencyCode);if(meta.exponent==0)return '${m.minorUnits}';return '${m.minorUnits~/meta.scale}.${(m.minorUnits%meta.scale).toString().padLeft(meta.exponent,'0')}';}
  @override void dispose(){_name.dispose();_amount.dispose();_currency.dispose();super.dispose();}
  Future<void> _save() async{try{final currency=_currency.text.trim().toUpperCase();final definition=RecurringExpenseDefinition(id:widget.initial?.id??'recurring-${DateTime.now().microsecondsSinceEpoch}',userId:widget.userId,name:_name.text,amount:Money(minorUnits:parseExpenseMinorUnits(_amount.text,currency),currencyCode:currency),categoryCode:_category,frequency:_frequency,enabled:_enabled,startDate:_start,endDate:_end,createdAt:widget.initial?.createdAt,updatedAt:DateTime.now().toUtc());if(widget.initial==null)await widget.service.createRecurring(definition);else await widget.service.updateRecurring(definition);if(mounted)Navigator.pop(context,true);}catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('FormatException: ','').replaceFirst('Invalid argument(s): ',''));}}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text(widget.initial==null?'تعريف مصروف متكرر':'تعديل مصروف متكرر'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:_name,decoration:const InputDecoration(labelText:'الاسم')),TextField(controller:_amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'المبلغ')),TextField(controller:_currency,textCapitalization:TextCapitalization.characters,maxLength:3,decoration:const InputDecoration(labelText:'العملة')),DropdownButtonFormField<String>(value:_category,decoration:const InputDecoration(labelText:'الفئة'),items:[for(final code in ExpenseCategories.codes)DropdownMenuItem(value:code,child:Text(ExpenseCategories.labelsAr[code]!))],onChanged:(v){if(v!=null)setState(()=>_category=v);}),DropdownButtonFormField<String>(value:_frequency,decoration:const InputDecoration(labelText:'التكرار'),items:const[DropdownMenuItem(value:'monthly',child:Text('شهري')),DropdownMenuItem(value:'weekly',child:Text('أسبوعي')),DropdownMenuItem(value:'biweekly',child:Text('كل أسبوعين')),DropdownMenuItem(value:'quarterly',child:Text('ربع سنوي')),DropdownMenuItem(value:'yearly',child:Text('سنوي'))],onChanged:(v){if(v!=null)setState(()=>_frequency=v);}),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('مفعّل'),value:_enabled,onChanged:(v)=>setState(()=>_enabled=v)),ListTile(contentPadding:EdgeInsets.zero,title:const Text('يبدأ من'),subtitle:Text(_start.toIsoString()),trailing:TextButton(onPressed:()async{final s=await showDatePicker(context:context,initialDate:DateTime(_start.year,_start.month,_start.day),firstDate:DateTime(2000),lastDate:DateTime(9999));if(s!=null&&mounted)setState(()=>_start=ExpenseDate(year:s.year,month:s.month,day:s.day));},child:const Text('اختار')),ListTile(contentPadding:EdgeInsets.zero,title:Text(_end==null?'بدون نهاية':'ينتهي ${_end!.toIsoString()}'),trailing:_end==null?TextButton(onPressed:()async{final s=await showDatePicker(context:context,initialDate:DateTime(_start.year,_start.month,_start.day),firstDate:DateTime(2000),lastDate:DateTime(9999));if(s!=null&&mounted)setState(()=>_end=ExpenseDate(year:s.year,month:s.month,day:s.day));},child:const Text('تحديد نهاية')):TextButton(onPressed:()=>setState(()=>_end=null),child:const Text('مسح')),if(_error!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:_save,child:const Text('حفظ'))]);
}
