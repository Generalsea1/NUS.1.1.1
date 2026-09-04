import 'package:flutter/material.dart';

import '../application/shopping_lifecycle_service.dart';
import '../domain/shopping_list.dart';
import 'shopping_list_details_page.dart';
import 'shopping_list_editor_page.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({
    super.key,
    required this.service,
    this.isArabic = true,
  });

  final ShoppingLifecycleService service;
  final bool isArabic;

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  List<ShoppingList> _lists = const <ShoppingList>[];
  bool _loading = true;
  bool _mutationBusy = false;
  String? _error;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading && mounted) {
      setState(() => _error = null);
    }
    try {
      final lists = await widget.service.getAllLists();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t('Could not load shopping lists.', 'تعذر تحميل قوائم المشتريات.');
      });
    }
  }

  Future<void> _create() async {
    if (_mutationBusy) return;
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ShoppingListEditorPage(isArabic: widget.isArabic),
      ),
    );
    if (!mounted || name == null || _mutationBusy) return;

    setState(() => _mutationBusy = true);
    try {
      await widget.service.createList(name: name);
      await _load();
    } on ArgumentError {
      _message(t('Please enter a valid list name.', 'اكتب اسم قائمة صحيح.'));
    } on Object {
      _message(t('Could not save the shopping list.', 'تعذر حفظ قائمة المشتريات.'));
      await _load();
    } finally {
      if (mounted) setState(() => _mutationBusy = false);
    }
  }

  Future<void> _edit(ShoppingList list) async {
    if (_mutationBusy) return;
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ShoppingListEditorPage(
          isArabic: widget.isArabic,
          initialName: list.name,
        ),
      ),
    );
    if (!mounted || name == null || _mutationBusy) return;

    setState(() => _mutationBusy = true);
    try {
      await widget.service.updateList(list.id, name: name);
      await _load();
    } on ArgumentError {
      _message(t('Please enter a valid list name.', 'اكتب اسم قائمة صحيح.'));
    } on Object {
      _message(t('Could not update the shopping list.', 'تعذر تعديل قائمة المشتريات.'));
      await _load();
    } finally {
      if (mounted) setState(() => _mutationBusy = false);
    }
  }

  Future<void> _delete(ShoppingList list) async {
    if (_mutationBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Delete shopping list?', 'تحذف قائمة المشتريات؟')),
        content: Text(
          t(
            'The list and all of its items will be removed.',
            'سيتم حذف القائمة وكل العناصر الموجودة فيها.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t('Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || _mutationBusy) return;

    setState(() => _mutationBusy = true);
    try {
      await widget.service.deleteList(list.id);
      await _load();
    } on Object {
      _message(t('Could not delete the shopping list.', 'تعذر حذف قائمة المشتريات.'));
      await _load();
    } finally {
      if (mounted) setState(() => _mutationBusy = false);
    }
  }

  Future<void> _open(ShoppingList list) async {
    if (_mutationBusy) return;
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShoppingListDetailsPage(
          service: widget.service,
          listId: list.id,
          isArabic: widget.isArabic,
        ),
      ),
    );
    if (!mounted || deleted != true) return;
    await _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Shopping', 'المشتريات'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mutationBusy ? null : _create,
        icon: _mutationBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: Text(t('New list', 'قائمة جديدة')),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load, isArabic: widget.isArabic)
                : RefreshIndicator(
                    onRefresh: _mutationBusy ? () async {} : _load,
                    child: _lists.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              _EmptyState(onAdd: _mutationBusy ? null : _create, isArabic: widget.isArabic),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                            itemCount: _lists.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final list = _lists[index];
                              return _ShoppingListCard(
                                list: list,
                                isArabic: widget.isArabic,
                                disabled: _mutationBusy,
                                onTap: () => _open(list),
                                onEdit: () => _edit(list),
                                onDelete: () => _delete(list),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({
    required this.list,
    required this.isArabic,
    required this.disabled,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingList list;
  final bool isArabic;
  final bool disabled;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final completed = list.items.where((item) => item.isCompleted).length;
    final summary = list.items.isEmpty
        ? t('No items yet', 'لسه مفيش عناصر')
        : '${list.items.length} ${t('items', 'عناصر')} • $completed ${t('done', 'مكتملة')}';

    return Card(
      elevation: 0,
      child: ListTile(
        onTap: disabled ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: const CircleAvatar(child: Icon(Icons.shopping_cart_outlined)),
        title: Text(
          list.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(summary),
        trailing: PopupMenuButton<String>(
          enabled: !disabled,
          onSelected: (value) {
            if (value == 'edit') onEdit();
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.isArabic});

  final VoidCallback? onAdd;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 48),
              const SizedBox(height: 14),
              Text(
                isArabic ? 'لسه مفيش قوائم مشتريات' : 'No shopping lists yet',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic
                    ? 'اعمل أول قائمة مشتريات وخلي كل احتياجاتك في مكان واحد.'
                    : 'Create your first shopping list and keep everything together.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(isArabic ? 'إنشاء قائمة' : 'Create list'),
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isArabic,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
              ),
            ],
          ),
        ),
      );
}
