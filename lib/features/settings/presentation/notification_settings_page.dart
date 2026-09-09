import 'package:flutter/material.dart';

import '../../../core/proactive_notification_coordinator.dart';
import '../../../core/proactive_recommendation_settings.dart';
import '../../../features/appointments/data/local_appointment_repository.dart';
import '../../../notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final NusProactiveNotificationCoordinator _coordinator;
  late final NusProactiveRecommendationSettings _recommendationSettings;
  bool _enabled = true;
  bool _recommendationsEnabled = true;
  bool _loading = true;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _coordinator = NusProactiveNotificationCoordinator(scheduler: NotificationService());
    _recommendationSettings = const NusProactiveRecommendationSettings();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _coordinator.isEnabled();
    final recommendationsEnabled = await _recommendationSettings.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _recommendationsEnabled = recommendationsEnabled;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    final appointments = await LocalAppointmentRepository().list();
    try {
      await _coordinator.setEnabled(
        enabled: value,
        now: DateTime.now(),
        appointments: appointments,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _enabled = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not update notification settings.', 'ماقدرتش أغيّر إعدادات التنبيهات.'))),
      );
    }
  }

  Future<void> _setRecommendationsEnabled(bool value) async {
    final previous = _recommendationsEnabled;
    setState(() => _recommendationsEnabled = value);
    try {
      await _recommendationSettings.setEnabled(value);
    } on Object {
      if (!mounted) return;
      setState(() => _recommendationsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not update recommendation settings.', 'ماقدرتش أغيّر إعدادات اقتراحات NUS.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            t('Notifications', 'التنبيهات'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                children: [
                  Card(
                    child: SwitchListTile.adaptive(
                      value: _enabled,
                      onChanged: _setEnabled,
                      secondary: const CircleAvatar(child: Icon(Icons.notifications_active_outlined)),
                      title: Text(
                        t('Proactive appointment reminders', 'التنبيهات الاستباقية للمواعيد'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        t(
                          'When an upcoming appointment has no reminder, NUS can alert you 30 minutes before it.',
                          'لما يكون عندك موعد قادم من غير تذكير محدد، NUS يقدر يفكّرك قبله بـ30 دقيقة.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SwitchListTile.adaptive(
                      key: const ValueKey<String>('proactive-recommendations-toggle'),
                      value: _recommendationsEnabled,
                      onChanged: _setRecommendationsEnabled,
                      secondary: const CircleAvatar(child: Icon(Icons.lightbulb_outline_rounded)),
                      title: Text(
                        t('NUS proactive suggestions', 'اقتراحات NUS الاستباقية'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        t(
                          'Show useful cross-domain suggestions on NUS Today. Turning this off does not disable your saved reminders.',
                          'إظهار اقتراحات مفيدة مبنية على بيانات NUS في Today. إيقافها لا يلغي التذكيرات المحفوظة.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.privacy_tip_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t(
                                'These proactive rules are generated locally from your saved appointments and NUS Today facts. NUS does not need an AI call to create them.',
                                'القواعد الاستباقية دي بتتكوّن محليًا من مواعيدك وبيانات NUS Today، ومش محتاجة أي استدعاء للذكاء الاصطناعي.',
                              ),
                              style: const TextStyle(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
