import 'package:flutter/material.dart';

import '../../../legacy_main.dart' as legacy;
import '../../ai/presentation/ai_hub_page.dart';
import '../../appointments/data/local_appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../settings/presentation/notification_settings_page.dart';
import '../data/speech_to_text_nus_voice_input.dart';
import '../domain/nus_daily_intelligence.dart';
import 'nus_quick_add_page.dart';

class NusTodayPage extends StatefulWidget {
  const NusTodayPage({
    super.key,
    required this.profile,
    this.scheduleStore,
    this.onOpenAppointments,
    this.onOpenFinance,
    this.onCreateReminder,
  });

  final HouseholdProfile profile;
  final legacy.ScheduleStore? scheduleStore;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenFinance;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;

  @override
  State<NusTodayPage> createState() => _NusTodayPageState();
}

class _NusTodayPageState extends State<NusTodayPage> {
  final LocalAppointmentRepository _appointments = LocalAppointmentRepository();
  List<Appointment> _appointmentItems = <Appointment>[];
  bool _loadingAppointments = true;

  @override
  void initState() {
    super.initState();
    widget.scheduleStore?.addListener(_onScheduleChanged);
    _loadAppointments();
  }

  @override
  void dispose() {
    widget.scheduleStore?.removeListener(_onScheduleChanged);
    super.dispose();
  }

  void _onScheduleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAppointments() async {
    setState(() => _loadingAppointments = true);
    final items = await _appointments.list();
    if (!mounted) return;
    setState(() {
      _appointmentItems = items;
      _loadingAppointments = false;
    });
  }

  Future<void> _openQuickAdd() async {
    final createReminder = widget.onCreateReminder;
    if (createReminder == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NusQuickAddPage(
          onCreateReminder: createReminder,
          voiceInput: SpeechToTextNusVoiceInput(),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openCopilot() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AiHubPage(isArabic: true)),
    );
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsPage(isArabic: true),
      ),
    );
  }

  String _money(int value) => '${_format(value)} ${widget.profile.currencyCode}';

  String _format(int value) {
    final text = value.abs().toString();
    final chunks = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      chunks.insert(0, text.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  List<legacy.ScheduleItem> _todayReminders(DateTime now) {
    final items = widget.scheduleStore?.items ?? const <legacy.ScheduleItem>[];
    final today = DateUtils.dateOnly(now);
    return items
        .where((item) => DateUtils.isSameDay(item.dateTime, today))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<legacy.ScheduleItem> _upcomingReminders(DateTime now) {
    final items = widget.scheduleStore?.items ?? const <legacy.ScheduleItem>[];
    return items
        .where((item) => !item.completed && item.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<void> _toggleReminder(legacy.ScheduleItem item) async {
    await widget.scheduleStore?.toggle(item);
  }

  Future<void> _removeReminder(legacy.ScheduleItem item) async {
    await widget.scheduleStore?.remove(item);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final todayAppointments = _appointmentItems
        .where((item) => DateUtils.isSameDay(item.startsAt, today))
        .where((item) => item.status != AppointmentStatus.cancelled)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final nextAppointments = _appointmentItems
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => item.startsAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final todayReminders = _todayReminders(now);
    final upcomingReminders = _upcomingReminders(now);
    final insights = NusDailyIntelligence.build(
      profile: widget.profile,
      appointments: _appointmentItems,
      now: now,
    );
    final focusCount = todayAppointments.length +
        todayReminders.where((item) => !item.completed).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NUS Today', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'إعدادات التنبيهات',
              onPressed: _openNotificationSettings,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loadingAppointments ? null : _loadAppointments,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      focusCount == 0
                          ? 'النهارده مفيش حاجة عاجلة في الجدول. NUS جاهز لأي إضافة جديدة.'
                          : 'عندك $focusCount ${focusCount == 1 ? 'حاجة' : 'حاجات'} محتاجة انتباه النهارده.',
                      style: TextStyle(
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.people_alt_outlined, '${widget.profile.householdSize} أفراد'),
                        _chip(Icons.payments_outlined, _money(widget.profile.remainingAfterObligations)),
                        _chip(Icons.flag_outlined, 'الالتزامات ${_money(widget.profile.recurringObligations)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _dailyBriefing(insights),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.add_task_rounded,
                    title: 'إضافة سريعة',
                    subtitle: 'سجّل تذكير في ثواني',
                    onTap: _openQuickAdd,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.auto_awesome_rounded,
                    title: 'NUS Copilot',
                    subtitle: 'اسأل NUS عن حياتك وبياناتك',
                    onTap: _openCopilot,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'فلوسي',
                    subtitle: 'الدخل والالتزامات والأهداف',
                    onTap: widget.onOpenFinance,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionCard(
                    context,
                    icon: Icons.event_available_rounded,
                    title: 'مواعيدي',
                    subtitle: 'المواعيد الحالية والقادمة',
                    onTap: widget.onOpenAppointments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              title: 'مهمات النهارده',
              icon: Icons.check_circle_outline_rounded,
              child: todayReminders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('مفيش تذكيرات للنهارده. أضف أول حاجة محتاج تفتكرها.'),
                    )
                  : Column(
                      children: [
                        for (final item in todayReminders) _reminderTile(item),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _section(
              title: 'مواعيد النهارده',
              icon: Icons.today_rounded,
              child: _loadingAppointments
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : todayAppointments.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('مفيش مواعيد مسجلة النهارده.'),
                        )
                      : Column(
                          children: [
                            for (final item in todayAppointments) _appointmentTile(item),
                          ],
                        ),
            ),
            const SizedBox(height: 14),
            _section(
              title: 'الخطوة الجاية',
              icon: Icons.arrow_circle_left_rounded,
              child: _nextAction(
                appointments: nextAppointments,
                reminders: upcomingReminders,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                onTap: _openCopilot,
                leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                title: const Text('NUS Copilot', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('المساعد الموجود بالفعل داخل NUS — بدون مفتاح Gemini على جهاز المستخدم.'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nextAction({
    required List<Appointment> appointments,
    required List<legacy.ScheduleItem> reminders,
  }) {
    final appointment = appointments.isEmpty ? null : appointments.first;
    final reminder = reminders.isEmpty ? null : reminders.first;
    if (appointment == null && reminder == null) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text('مفيش حاجة جاية مسجلة. NUS فاضي وجاهز للي بعده.'),
      );
    }

    if (appointment != null && (reminder == null || appointment.startsAt.isBefore(reminder.dateTime))) {
      return _appointmentTile(appointment);
    }
    return _reminderTile(reminder!);
  }

  Widget _dailyBriefing(List<NusDailyInsight> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Icon(Icons.psychology_alt_rounded)),
              title: Text('NUS Morning Brief', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              subtitle: Text('ملخص عملي مبني على بياناتك الحالية، بدون تخمين.'),
            ),
            const Divider(height: 1),
            for (final insight in insights)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(insight.icon),
                title: Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(insight.message),
              ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير 👋';
    if (hour < 18) return 'مساء الخير 👋';
    return 'مساء الخير 🌙';
  }

  Widget _chip(IconData icon, String text) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );

  Widget _section({required String title, required IconData icon, required Widget child}) => Card(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(child: Icon(icon)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const Divider(height: 1),
            child,
          ],
        ),
      );

  Widget _appointmentTile(Appointment item) {
    final time = TimeOfDay.fromDateTime(item.startsAt).format(context);
    return ListTile(
      leading: Icon(
        item.isDoctor
            ? Icons.medical_services_outlined
            : item.isScheduledCall
                ? Icons.phone_callback_rounded
                : Icons.event_rounded,
      ),
      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$time${item.location == null ? '' : ' • ${item.location}'}'),
    );
  }

  Widget _reminderTile(legacy.ScheduleItem item) {
    final time = TimeOfDay.fromDateTime(item.dateTime).format(context);
    return ListTile(
      key: ValueKey<String>('today-reminder-${item.id}'),
      leading: Checkbox(
        value: item.completed,
        onChanged: (_) => _toggleReminder(item),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          decoration: item.completed ? TextDecoration.lineThrough : TextDecoration.none,
        ),
      ),
      subtitle: Text(time),
      trailing: IconButton(
        tooltip: 'حذف',
        onPressed: () => _removeReminder(item),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }
}
