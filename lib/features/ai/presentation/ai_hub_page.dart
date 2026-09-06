import 'package:flutter/material.dart';

import '../../../core/auth/google_auth_repository.dart';
import '../../../core/supabase_service.dart';
import 'ai_history_page.dart';
import 'ai_settings_page.dart';

class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key, this.isArabic = true});
  final bool isArabic;

  String _t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.client?.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(_t('AI manager', 'مدير الذكاء الاصطناعي'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_t('Your personal intelligence layer', 'طبقة الذكاء الشخصية بتاعتك'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(user == null
                    ? _t('Sign in with Google first, then connect an AI provider.', 'سجّل دخولك بجوجل الأول، وبعدها اربط مزود الذكاء الاصطناعي.')
                    : _t('Signed in as ${user.email ?? 'NUS user'}', 'مسجل دخول باسم ${user.email ?? 'مستخدم NUS'}')),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (user == null)
            FilledButton.icon(
              onPressed: () async {
                final started = await const GoogleAuthRepository().signIn();
                if (!started && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('Google sign-in is not configured yet.', 'تسجيل دخول جوجل مش متظبط على المشروع لسه.'))));
                }
              },
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(_t('Continue with Google', 'الدخول بحساب Google')),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: isArabic))),
              icon: const Icon(Icons.link_rounded),
              label: Text(_t('AI provider connections', 'اتصالات مزودي الذكاء الاصطناعي')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiHistoryPage(isArabic: isArabic))),
              icon: const Icon(Icons.history_rounded),
              label: Text(_t('My AI history', 'سجل تحليلاتي بالذكاء الاصطناعي')),
            ),
          ],
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_t(
                'AI results are stored under your NUS account. NUS does not store your Google password or return provider tokens to the app.',
                'نتائج الذكاء الاصطناعي بتتخزن تحت حسابك في NUS. البرنامج مش بيخزن باسورد Google ومش بيرجع Tokens الخاصة بالمزود للتطبيق.',
              )),
            ),
          ),
        ],
      ),
    );
  }
}
