import 'package:flutter/material.dart';

import '../application/obligation_service.dart';
import '../data/supabase_obligation_repository.dart';
import '../domain/obligation.dart';

class ObligationManagementPage extends StatefulWidget {
  const ObligationManagementPage({super.key, required this.userId, required this.householdCurrencyCode, this.service});
  final String userId;
  final String householdCurrencyCode;
  final ObligationService? service;
  @override
  State<ObligationManagementPage> createState() => _ObligationManagementPageState();
}

class _ObligationManagementPageState extends State<ObligationManagementPage> {
  late final ObligationService _service = widget.service ?? const ObligationService(repository: SupabaseObligationRepository());
  List<Obligation> _items = const <Obligation>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await _service.list(widget.userId);
      if (!mounted) return;
      setState(() { _items = List<Obligation>.of(items, growable: false); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'تعذر تحميل الالتزامات الآن. جرّب مرة تانية.'; });
    }
  }

  Future<void> _edit([Obligation? existing]) async {
    final result = await showModalBottomSheet<ObligationDraft>(
      context: context, isScrollControlled: true, builder: (_) => _ObligationForm(existing: existing, currencyCode: widget.householdCurrencyCode),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await _service.create(Obligation(userId: widget.userId, name: result.name, type: result.type, amount: result.amount, currencyCode: widget.householdCurrencyCode, frequency: result.frequency, enabled: true));
      } else {
        await _service.update(existing.copyWith(name: result.name, type: result.type, amount: result.amount, frequency: result.frequency, currencyCode: widget.householdCurrencyCode));
      }
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماقدرناش نحفظ الالتزام. حاول تاني.')));
    }
  }

  Future<void> _toggle(Obligation item) async {
    try { await _service.setEnabled(widget.userId, item.id!, !item.enabled); await _load(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماقدرناش نغيّر حالة الالتزام. حاول تاني.'))); }
  }

  Future<void> _delete(Obligation item) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف الالتزام؟'), content: Text('هيتم حذف «${item.name}» نهائيًا من حسابك.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))],
    ));
    if (ok != true) return;
    try { await _service.delete(widget.userId, item.id!); await _load(); }
    catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ماقدرناش نحذف الالتزام. الالتزام ما زال محفوظًا.'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الالتزامات المتكررة', style: TextStyle(fontWeight: FontWeight.w900))),
    floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('إضافة التزام')),
    body: SafeArea(child: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _errorView() : _items.isEmpty ? _emptyView() : RefreshIndicator(onRefresh: _load, child: ListView.separated(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _tile(_items[i])))),
  );

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 48), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة'))])));
  Widget _emptyView() => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.account_balance_wallet_outlined, size: 54), const SizedBox(height: 14), const Text('لسه مفيش التزامات متكررة مسجلة.', textAlign: TextAlign.center), const SizedBox(height: 10), const Text('أضف الإيجار أو الأقساط أو أي التزام ثابت تعرفه.', textAlign: TextAlign.center)])));

  Widget _tile(Obligation item) {
    final label = ObligationTypes.labels[item.type] ?? item.type;
    return Card(child: ListTile(
      leading: CircleAvatar(child: Icon(item.enabled ? Icons.receipt_long_rounded : Icons.pause_circle_outline_rounded)),
      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$label · ${ObligationFrequencies.labels[item.frequency] ?? item.frequency}\n${item.amount} ${item.currencyCode} شهريًا بعد التطبيع: ${item.normalizedMonthlyAmount}'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'edit') _edit(item); if (value == 'toggle') _toggle(item); if (value == 'delete') _delete(item); }, itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'toggle', child: Text(item.enabled ? 'تعطيل' : 'تفعيل')), const PopupMenuItem(value: 'delete', child: Text('حذف')),
      ]),
    ));
  }
}

class ObligationDraft { const ObligationDraft({required this.name, required this.type, required this.amount, required this.frequency}); final String name; final String type; final int amount; final String frequency; }

class _ObligationForm extends StatefulWidget {
  const _ObligationForm({this.existing, required this.currencyCode});
  final Obligation? existing; final String currencyCode;
  @override State<_ObligationForm> createState() => _ObligationFormState();
}
class _ObligationFormState extends State<_ObligationForm> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _amount = TextEditingController(text: widget.existing?.amount.toString() ?? '');
  late String _type = widget.existing?.type ?? 'rent';
  late String _frequency = widget.existing?.frequency ?? 'monthly';
  String? _error;
  @override void dispose() { _name.dispose(); _amount.dispose(); super.dispose(); }
  void _save() {
    final name = _name.text.trim(); final amount = int.tryParse(_amount.text.trim());
    if (name.isEmpty) { setState(() => _error = 'اكتب اسم الالتزام.'); return; }
    if (amount == null || amount <= 0) { setState(() => _error = 'المبلغ لازم يكون رقم صحيح أكبر من صفر.'); return; }
    Navigator.of(context).pop(ObligationDraft(name: name, type: _type, amount: amount, frequency: _frequency));
  }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
    Text(widget.existing == null ? 'إضافة التزام' : 'تعديل الالتزام', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 16),
    TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الالتزام', prefixIcon: Icon(Icons.label_outline))), const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _type, decoration: const InputDecoration(labelText: 'النوع'), items: ObligationTypes.values.map((v) => DropdownMenuItem(value: v, child: Text(ObligationTypes.labels[v] ?? v))).toList(growable: false), onChanged: (v) => setState(() => _type = v ?? 'other')), const SizedBox(height: 12),
    TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: false), decoration: InputDecoration(labelText: 'المبلغ الدوري', helperText: 'العملة: ${widget.currencyCode}')), const SizedBox(height: 12),
    DropdownButtonFormField<String>(initialValue: _frequency, decoration: const InputDecoration(labelText: 'التكرار'), items: ObligationFrequencies.values.map((v) => DropdownMenuItem(value: v, child: Text(ObligationFrequencies.labels[v] ?? v))).toList(growable: false), onChanged: (v) => setState(() => _frequency = v ?? 'monthly')), if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))), const SizedBox(height: 16), FilledButton(onPressed: _save, child: const Text('حفظ')),
  ])));
}
