import 'package:flutter/material.dart';

import '../application/shopping_lifecycle_service.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'shopping_list_editor_page.dart';

class ShoppingListDetailsPage extends StatefulWidget {
  const ShoppingListDetailsPage({
    super.key,
    required this.service,
    required this.listId,
    this.isArabic = true,
  });

  final ShoppingLifecycleService service;
  final String listId;
  final bool isArabic;

  @override
  State<ShoppingListDetailsPage> createState() => _ShoppingListDetailsPageState();
}

class _ShoppingListDetailsPageState extends State<ShoppingListDetailsPage> {
  ShoppingList? _list;
  bool _loading = true;
  String? _error;
  final Set<String> _busyItems = <String>{};
  bool _listActionBusy = false;

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
      final list = await widget.service.getList(widget.listId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
        _error = list == null
            ? t('Shopping list was not found.', 'قائمة المشتريات غير موجودة.')
            : null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t('Could not load this shopping list.', 'تعذر تحميل قائمة المشتريات.');
      });
    }
  }

  Future<void> _editList() async {
    final list = _list;
    if (list == null) return;
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ShoppingListEditorPage(
          initialName: list.name,
          isArabic: widget.isArabic,
        ),
      ),
    );
    if (!mounted || name == null) return;

    try {
      final updated = await widget.service.updateList(widget.listId, name: name);
      if (!mounted) return;
      setState(() => _list = updated);
    } on Object {
      _message(t('Could not update the shopping list.', 'تعذر تعديل قائمة المشتريات.'));
    }
  }

  Future<void> _deleteList() async {
    if (_list == null || _listActionBusy) return;
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
    if (!mounted || confirmed != true) return;

    setState(() => _listActionBusy = true);
    try {
      await widget.service.deleteList(widget.listId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() => _listActionBusy = false);
      _message(t('Could not delete the shopping list.', 'تعذر حذف قائمة المشتريات.'));
    }
  }

  Future<void> _addItem() async {
    final draft = await showModalBottomSheet<_ShoppingItemDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShoppingItemEditorSheet(isArabic: widget.isArabic),
    );
    if (!mounted || draft == null) return;

    try {
      final updated = await widget.service.addItem(
        widget.listId,
        name: draft.name,
        quantity: draft.quantity,
      );
      if (!mounted) return;
      setState(() => _list = updated);
    } on Object {
      _message(t('Could not add the item.', 'تعذر إضافة العنصر.'));
    }
  }

  Future<void> _editItem(ShoppingItem item) async {
    final draft = await showModalBottomSheet<_ShoppingItemDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ShoppingItemEditorSheet(
        initial: item,
        isArabic: widget.isArabic,
      ),
    );
    if (!mounted || draft == null) return;

    try {
      final updated = await widget.service.updateItem(
        widget.listId,
        item.copyWith(
          name: draft.name,
          quantity: draft.quantity,
          clearQuantity: draft.quantity == null,
        ),
      );
      if (!mounted) return;
      setState(() => _list = updated);
    } on Object {
      _message(t('Could not update the item.', 'تعذر تعديل العنصر.'));
    }
  }

  Future<void> _toggleItem(ShoppingItem item) async {
    if (_busyItems.contains(item.id)) return;
    setState(() => _busyItems.add(item.id));
    try {
      final updated = await widget.service.toggleItemCompletion(widget.listId, item.id);
      if (!mounted) return;
      setState(() => _list = updated);
    } on Object {
      if (mounted) {
        _message(t('Could not update item completion.', 'تعذر تحديث حالة العنصر.'));
      }
    } finally {
      if (mounted) setState(() => _busyItems.remove(item.id));
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    if (_busyItems.contains(item.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Delete item?', 'تحذف العنصر؟')),
        content: Text(item.name),
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
    if (!mounted || confirmed != true) return;

    setState(() => _busyItems.add(item.id));
    try {
      final updated = await widget.service.removeItem(widget.listId, item.id);
      if (!mounted) return;
      setState(() => _list = updated);
    } on Object {
      if (mounted) {
        _message(t('Could not delete the item.', 'تعذر حذف العنصر.'));
      }
    } finally {
      if (mounted) setState(() => _busyItems.remove(item.id));
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          list?.name ?? t('Shopping list', 'قائمة المشتريات'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (list != null)
            PopupMenuButton<String>(
              enabled: !_listActionBusy,
              onSelected: (value) {
                if (value == 'edit') _editList();
                if (value == 'delete') _deleteList();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(t('Edit list', 'تعديل القائمة'))),
                PopupMenuItem(value: 'delete', child: Text(t('Delete list', 'حذف القائمة'))),
              ],
            ),
        ],
      ),
      floatingActionButton: list == null || _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded),
              label: Text(t('Add item', 'إضافة عنصر')),
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load, isArabic: widget.isArabic)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list!.items.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 100),
                              _EmptyItemsState(onAdd: _addItem, isArabic: widget.isArabic),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                            itemCount: list.items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = list.items[index];
                              return _ShoppingItemTile(
                                item: item,
                                isArabic: widget.isArabic,
                                busy: _busyItems.contains(item.id),
                                onToggle: () => _toggleItem(item),
                                onEdit: () => _editItem(item),
                                onDelete: () => _deleteItem(item),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.isArabic,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItem item;
  final bool isArabic;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final quantity = item.quantity?.trim();
    final subtitle = quantity == null || quantity.isEmpty ? null : quantity;
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: busy ? null : onEdit,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Checkbox.adaptive(
          value: item.isCompleted,
          onChanged: busy ? null : (_) => onToggle(),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
            color: item.isCompleted ? Colors.grey.shade600 : null,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: PopupMenuButton<String>(
          enabled: !busy,
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

class _ShoppingItemDraft {
  const _ShoppingItemDraft({required this.name, required this.quantity});

  final String name;
  final String? quantity;
}

class _ShoppingItemEditorSheet extends StatefulWidget {
  const _ShoppingItemEditorSheet({this.initial, required this.isArabic});

  final ShoppingItem? initial;
  final bool isArabic;

  @override
  State<_ShoppingItemEditorSheet> createState() => _ShoppingItemEditorSheetState();
}

class _ShoppingItemEditorSheetState extends State<_ShoppingItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;

  bool get _editing => widget.initial != null;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _quantity = TextEditingController(text: widget.initial?.quantity ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _save() {
    final cleanName = _name.text.trim();
    if (cleanName.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t('Item name is required.', 'اسم العنصر مطلوب.'))),
        );
      return;
    }

    final cleanQuantity = _quantity.text.trim();
    final draft = _ShoppingItemDraft(
      name: cleanName,
      quantity: cleanQuantity.isEmpty ? null : cleanQuantity,
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              _editing ? t('Edit item', 'تعديل العنصر') : t('Add item', 'إضافة عنصر'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('shopping_item_name_field'),
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t('Item name *', 'اسم العنصر *'),
                prefixIcon: const Icon(Icons.shopping_basket_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('shopping_item_quantity_field'),
              controller: _quantity,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                labelText: t('Quantity (optional)', 'الكمية (اختياري)'),
                prefixIcon: const Icon(Icons.numbers_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('shopping_item_editor_save'),
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(t('Save item', 'حفظ العنصر')),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const Key('shopping_item_editor_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t('Cancel', 'إلغاء')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({required this.onAdd, required this.isArabic});

  final VoidCallback onAdd;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              const Icon(Icons.shopping_basket_outlined, size: 48),
              const SizedBox(height: 14),
              Text(
                isArabic ? 'لسه مفيش عناصر' : 'No items yet',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                isArabic ? 'أضف أول عنصر للقائمة.' : 'Add the first item to this list.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(isArabic ? 'إضافة عنصر' : 'Add item'),
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry, required this.isArabic});

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
