import 'package:flutter/material.dart';

void main() => runApp(const NosApp());

class NosApp extends StatefulWidget {
  const NosApp({super.key});
  @override State<NosApp> createState() => _NosAppState();
}

class _NosAppState extends State<NosApp> {
  bool arabic = true;
  final List<String> schedules = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOS',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)), scaffoldBackgroundColor: const Color(0xFFF7F7FB)),
      home: Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr, child: HomePage(
        arabic: arabic, schedules: schedules,
        onLanguage: () => setState(() => arabic = !arabic),
        onAdd: (value) => setState(() => schedules.add(value)),
      )),
    );
  }
}

class HomePage extends StatelessWidget {
  final bool arabic; final List<String> schedules; final VoidCallback onLanguage; final ValueChanged<String> onAdd;
  const HomePage({super.key, required this.arabic, required this.schedules, required this.onLanguage, required this.onAdd});
  String t(String en, String ar) => arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Row(children: [Icon(Icons.auto_awesome_rounded), SizedBox(width: 8), Text('NOS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))]), actions: [TextButton(onPressed: onLanguage, child: Text(t('العربية','English')))]),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 40), children: [
        Text(t('Good day','أهلًا بيك'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(t('What’s on your mind?','إيه اللي وراك؟'), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.0)),
        const SizedBox(height: 12),
        Text(t('Tell NOS what you need to remember. We’ll keep your day organized.','قول لـ NOS إيه اللي محتاج تفتكره، وإحنا نرتّب يومك.'), style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4)),
        const SizedBox(height: 22),
        FilledButton.icon(onPressed: () => showAdd(context), icon: const Icon(Icons.add_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(t('Add schedule','إضافة موعد'), style: const TextStyle(fontWeight: FontWeight.w900)))),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t('Today','النهارده'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text('${schedules.length}')]),
        const SizedBox(height: 12),
        if (schedules.isEmpty) Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [const Icon(Icons.check_circle_outline_rounded, size: 34), const SizedBox(width: 14), Expanded(child: Text(t('Nothing scheduled yet. Add your first reminder.','لسه مفيش مواعيد. ضيف أول تذكير وخليه من دماغك.')))])))
        else ...schedules.map((x) => Card(color: Colors.white, child: ListTile(leading: const Icon(Icons.event_available_rounded), title: Text(x), trailing: const Icon(Icons.chevron_left_rounded)))),
      ]),
    );
  }

  Future<void> showAdd(BuildContext context) async {
    final controller = TextEditingController();
    await showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t('New schedule','موعد جديد'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 16),
        TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: t('What do you need to remember?','إيه اللي محتاج تفتكره؟'))), const SizedBox(height: 14),
        FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) { onAdd(controller.text.trim()); Navigator.pop(ctx); } }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t('Save reminder','احفظ التذكير')))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('Cancel','إلغاء'))),
      ]),
    ));
  }
}
