import 'package:flutter/material.dart';

import '../../../core/theme/nus_theme.dart';
import '../../../core/utils/nus_date_utils.dart';
import '../../appointments/application/appointment_service.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointment_form_page.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../schedule/data/schedule_store.dart';
import '../domain/nus_daily_intelligence.dart';
import '../../ai/presentation/nus_ai_hub_page.dart';
import '../../settings/presentation/about_nus_page.dart';
import '../../settings/presentation/notification_settings_page.dart';
import 'nus_quick_add_page.dart';

class NusTodayPage extends StatefulWidget {
  const NusTodayPage({
    super.key,
    required this.profile,
  });

  final HouseholdProfile profile;

  @override
  State<NusTodayPage> createState() => _NusTodayPageState();
}

class _NusTodayPageState extends State<NusTodayPage> {
  final _appointmentService = AppointmentService();
  final _expenseService = ExpenseManagementService();

  List<Appointment> _appointmentItems = const [];
  bool _loadingAppointments = true;
  bool _loadingSpending = true;
  int _monthlyActual = 0;
  Object? _spendingError;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
    ScheduleStore.instance.addListener(_onScheduleChanged);
  }

  @override
  void dispose() {
    ScheduleStore.instance.removeListener(_onScheduleChanged);
    super.dispose();
  }

  void _onScheduleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTodayData() async {
    await Future.wait([
      _loadAppointments(),
      _loadSpending(),
    ]);
  }

  Future<void> _loadAppointments() async {
    try {
      final items = await _appointmentService.listAll();
      if (!mounted) return;
      setState(() {
        _appointmentItems = items;
        _loadingAppointments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appointmentItems = const [];
        _loadingAppointments = false;
      });
    }
  }

  Future<void> _loadSpending() async {
    try {
      final total = await _expenseService.monthlyActualTotal(DateTime.now());
      if (!mounted) return;
      setState(() {
        _monthlyActual = total;
        _spendingError = null;
        _loadingSpending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _spendingError = error;
        _loadingSpending = false;
      });
    }
  }

  Future<void> _openQuickAdd() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NusQuickAddPage(),
      ),
    );
    if (mounted) {
      await _loadTodayData();
    }
  }

  Future<void> _openCopilot() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NusAiHubPage(),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsPage(),
      ),
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AboutNusPage(),
      ),
    );
  }

  List<ScheduleItem> _todayReminders(DateTime now) {
    return ScheduleStore.instance.items
        .where((item) => NusDateUtils.isSameDay(item.dateTime, now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<ScheduleItem> _upcomingReminders(DateTime now) {
    return ScheduleStore.instance.items
        .where((item) => !item.completed && item.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayAppointments = _appointmentItems
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => NusDateUtils.isSameDay(item.startsAt, now))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final todayReminders = _todayReminders(now);
    final upcomingReminders = _upcomingReminders(now);
    final upcomingTodayReminders = todayReminders
        .where((item) => !item.completed && item.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final insights = NusDailyIntelligence.build(
      profile: widget.profile,
      appointments: _appointmentItems,
      pendingReminderCount: upcomingReminders.length,
      nextReminderTitle: upcomingTodayReminders.isEmpty ? null : upcomingTodayReminders.first.title,
      nextReminderAt: upcomingTodayReminders.isEmpty ? null : upcomingTodayReminders.first.dateTime,
      now: now,
    );
    final focusCount = todayAppointments.length +
        todayReminders.where((item) => !item.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NUS Today'),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: _openSettings,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                _openAbout();
              } else if (value == 'copilot') {
                _openCopilot();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'copilot',
                child: Text('NUS Copilot'),
              ),
              PopupMenuItem(
                value: 'about',
                child: Text('عن NUS'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة سريعة'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _heroCard(context, focusCount),
            const SizedBox(height: 12),
            _section(
              context,
              title: 'ملخص صباحك',
              icon: Icons.auto_awesome_rounded,
              child: _dailyBriefing(context, insights),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: 'الوضع المالي',
              icon: Icons.account_balance_wallet_outlined,
              child: _spendingSnapshot(context),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: 'أقرب خطوة',
              icon: Icons.north_east_rounded,
              child: _nextAction(context, todayAppointments, upcomingTodayReminders),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: 'مواعيد اليوم',
              icon: Icons.event_available_rounded,
              child: _appointmentsList(context, todayAppointments),
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: 'تذكيرات اليوم',
              icon: Icons.check_circle_outline_rounded,
              child: _remindersList(context, todayReminders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, int focusCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'صباح الخير 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'NUS شايف يومك في صورة واحدة بدل ما تفتح كل أداة لوحدها.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(context, Icons.today_rounded, '$focusCount حاجة مهمة النهارده'),
              _pill(context, Icons.family_restroom_rounded, '${widget.profile.householdSize} أفراد'),
              _pill(context, Icons.currency_exchange_rounded, widget.profile.currencyCode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _dailyBriefing(BuildContext context, List<NusDailyInsight> insights) {
    if (insights.isEmpty) {
      return const Text('لسه مفيش رؤى كفاية. أضف أول مهمة أو التزام عشان NUS يبدأ يقرأ يومك.');
    }
    return Column(
      children: [
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(insight.icon, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(insight.message),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _spendingSnapshot(BuildContext context) {
    if (_loadingSpending) return const LinearProgressIndicator();
    if (_spendingError != null) {
      return Text('تعذر قراءة مصروفات الشهر حاليًا. ${_spendingError}');
    }

    final dailyAverage = DateTime.now().day == 0
        ? 0
        : (_monthlyActual / DateTime.now().day).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_monthlyActual} ${widget.profile.currencyCode}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text('المصروف الفعلي هذا الشهر'),
        const SizedBox(height: 10),
        Text('متوسط الصرف اليومي حتى الآن: $dailyAverage ${widget.profile.currencyCode}'),
      ],
    );
  }

  Widget _nextAction(
    BuildContext context,
    List<Appointment> todayAppointments,
    List<ScheduleItem> upcomingTodayReminders,
  ) {
    Appointment? appointment = todayAppointments.isEmpty ? null : todayAppointments.first;
    ScheduleItem? reminder = upcomingTodayReminders.isEmpty ? null : upcomingTodayReminders.first;

    if (appointment == null && reminder == null) {
      return const Text('مفيش خطوة قادمة واضحة دلوقتي. استخدم الإضافة السريعة وأدخل الحاجة اللي في دماغك.');
    }

    final bool useReminder = reminder != null &&
        (appointment == null || reminder.dateTime.isBefore(appointment.startsAt));
    final title = useReminder ? reminder!.title : appointment!.title;
    final time = useReminder ? reminder!.dateTime : appointment!.startsAt;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(useReminder ? Icons.check_rounded : Icons.event_available_rounded),
      ),
      title: Text(title.isEmpty ? 'مهمة بدون اسم' : title),
      subtitle: Text('اليوم ${TimeOfDay.fromDateTime(time).format(context)}'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _appointmentsList(BuildContext context, List<Appointment> items) {
    if (_loadingAppointments) return const LinearProgressIndicator();
    if (items.isEmpty) return const Text('مفيش مواعيد قادمة مسجلة النهارده.');

    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(item.title),
            subtitle: Text(TimeOfDay.fromDateTime(item.startsAt).format(context)),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppointmentFormPage(existing: item),
                ),
              );
              if (mounted) await _loadAppointments();
            },
          ),
      ],
    );
  }

  Widget _remindersList(BuildContext context, List<ScheduleItem> items) {
    if (items.isEmpty) return const Text('مفيش تذكيرات مسجلة لليوم.');

    return Column(
      children: [
        for (final item in items)
          CheckboxListTile(
            dense: true,
            value: item.completed,
            contentPadding: EdgeInsets.zero,
            title: Text(item.title),
            subtitle: Text(TimeOfDay.fromDateTime(item.dateTime).format(context)),
            onChanged: (_) async {
              await ScheduleStore.instance.toggleCompleted(item.id);
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}
