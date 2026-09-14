import 'package:flutter/material.dart';

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final title = isArabic ? 'ذكاء NUS مُدار تلقائيًا' : 'NUS intelligence is managed automatically';
    final message = isArabic
        ? 'لا تحتاج لإضافة مفتاح Gemini أو اختيار مزود أو إعداد اتصال. NUS يستخدم خدمة الذكاء المؤمّنة من الخادم عندما تكون الميزة متاحة.'
        : 'You do not need to add a Gemini key, choose a provider, or configure an AI connection. NUS uses its secured server-side intelligence service when available.';

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.auto_awesome_rounded, size: 52),
                      const SizedBox(height: 16),
                      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(isArabic ? 'تمام' : 'Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
