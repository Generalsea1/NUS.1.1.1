import 'package:flutter/material.dart';

class AboutNusPage extends StatelessWidget {
  const AboutNusPage({super.key, this.isArabic = true});

  final bool isArabic;

  String _t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t('About NUS', 'عن NUS'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
          children: [
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.hub_rounded,
                        size: 42,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'NUS',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'Personal + Household Life Operating System',
                        'نظام تشغيل للحياة الشخصية والبيت',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Created by Talaat Moussa', 'من تصميم وتطوير طلعت موسى'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'NUS was designed and developed by Talaat Moussa, with assistance from OpenAI AI tools.',
                        'تم تصميم وتطوير NUS بواسطة طلعت موسى، بمساعدة أدوات الذكاء الاصطناعي من OpenAI.',
                      ),
                      style: const TextStyle(fontSize: 16, height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.rocket_launch_rounded),
                title: Text(
                  _t('Built for ambitious people', 'اتعمل للطموح'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  _t(
                    'The goal is simple: turn everyday life data into useful decisions, actions, and better routines.',
                    'الفكرة بسيطة: نحول بيانات الحياة اليومية إلى قرارات مفيدة وخطوات عملية وعادات أفضل.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: scheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.security_rounded),
                title: Text(
                  _t('Privacy is a product feature', 'الخصوصية جزء من المنتج'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  _t(
                    'NUS keeps core features useful without forcing an AI account, and keeps provider credentials behind secure server-side boundaries.',
                    'NUS يفضل شغال في الأساس من غير ما يجبرك على حساب AI، وبيحافظ على بيانات مزودي الذكاء خلف حدود آمنة على الخادم.',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'NUS 2.0',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
