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
                Text(_t('Your personal intelligence layer', 'طبقة الذكاء الاصطناعي الخاصة بك'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(user?.email ?? _t('Not signed in', 'مش مسجل دخول')),
                const SizedBox(height: 14),
                if (user == null)
                  FilledButton.icon(
                    onPressed: () async {
                      await const GoogleAuthRepository().signIn();
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_t('Continue with Google', 'الدخول بحساب Google')),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: Text(_t('AI providers', 'مزودو الذكاء الاصطناعي')),
              subtitle: Text(_t('Connect your own authorized provider.', 'اربط مزود الذكاء الاصطناعي الخاص بيك.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: user == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: isArabic))),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: Text(_t('AI history', 'سجل الذكاء الاصطناعي')),
              subtitle: Text(_t('Your saved household planning runs.', 'كل تحليلات إدارة البيت المحفوظة في حسابك.')),
              trailing: const Icon(Icons.chevron_right),
              onTap: user == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiHistoryPage(isArabic: isArabic))),
            ),
          ),
        ],
      ),
    );
  }
}
