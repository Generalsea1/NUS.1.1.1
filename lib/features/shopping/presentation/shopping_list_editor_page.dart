import 'package:flutter/material.dart';

class ShoppingListEditorPage extends StatefulWidget {
  const ShoppingListEditorPage({
    super.key,
    this.initialName,
    this.isArabic = true,
  });

  final String? initialName;
  final bool isArabic;

  @override
  State<ShoppingListEditorPage> createState() => _ShoppingListEditorPageState();
}

class _ShoppingListEditorPageState extends State<ShoppingListEditorPage> {
  late final TextEditingController _name;

  bool get _editing => widget.initialName != null;
  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final cleanName = _name.text.trim();
    if (cleanName.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(t('List name is required.', 'اسم القائمة مطلوب.'))),
        );
      return;
    }

    Navigator.of(context).pop(cleanName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? t('Edit shopping list', 'تعديل قائمة المشتريات') : t('New shopping list', 'قائمة مشتريات جديدة'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          tooltip: t('Cancel', 'إلغاء'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            key: const Key('shopping_list_name_field'),
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: t('List name *', 'اسم القائمة *'),
              hintText: t('Groceries', 'مشتريات البيت'),
              prefixIcon: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('shopping_list_editor_save'),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _editing ? t('Save changes', 'حفظ التعديلات') : t('Create list', 'إنشاء القائمة'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('shopping_list_editor_cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('Cancel', 'إلغاء')),
          ),
        ],
      ),
    );
  }
}
