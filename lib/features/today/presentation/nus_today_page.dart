import 'package:flutter/material.dart';

import '../../../legacy_main.dart' as legacy;
import '../../ai/presentation/ai_hub_page.dart';
import '../../appointments/data/local_appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../settings/presentation/about_nus_page.dart';
import '../../settings/presentation/notification_settings_page.dart';
import '../data/speech_to_text_nus_voice_input.dart';
import '../domain/nus_daily_intelligence.dart';
import 'nus_quick_add_page.dart';

class NusTodayPage extends StatefulWidget {
  const NusTodayPage({
    super.key,
    required this.profile,
    this.scheduleStore,
    this.expenseManagementService,
    this.onOpenAppointments,
    this.onOpenFinance,
    this.onCreateReminder,
  });

  final HouseholdProfile profile;
  final legacy.ScheduleStore? scheduleStore;
  final ExpenseManagementService? expenseManagementService;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenFinance;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;

  @override
  State<NusTodayPage> createState() => _NusTodayPageState();
}

class _NusTodayPageState extends State<NusTodayPage> {
  final LocalAppointmentRepository _appointments = LocalAppointmentRepository();

  List<Appointment> _appointmentItems = const [];
  bool _loadingAppointments = true;
  bool _loadingSpending = true;
  int? _monthlyActual;
  Object? _spendingError;

  @override
  void initState() {
    super.initState();
    widget.scheduleStore?.addListener(_onScheduleChanged);
    _loadAppointments();
    _loadSpending();
  }

  @override
  void didUpdateWidget(covariant NusTodayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleStore != widget.scheduleStore) {
      oldWidget.scheduleStore?.removeListener(_onScheduleChanged);
      widget.scheduleStore?.addListener(_onScheduleChanged);
    }
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
    if (mounted) setState(() => _loadingAppointments = true);
    try {
      final items = await _appointments.list();
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
    final service = widget.expenseManagementService;
    if (service == null) {
      if (mounted) setState(() => _loadingSpending = false);
      return;
    }

    if (mounted) {
      setState(() {
        _loadingSpending = true;
        _spendingError = null;
      });
    }

    try {
      final now = DateTime.now();
      final total = await service.monthlyActualTotal(
        year: now.year,
        month: now.month,
        currencyCode: widget.profile.currencyCode,
      );
      if (!mounted) return;
      setState(() {
        _monthlyActual = total;
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
    final createReminder = widget.onCreateReminder;
    if (createReminder == null) {
      _showMessage('الإضافة السريعة غير متاحة في الإعداد الحالي.');
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NusQuickAddPage(
          onCreateReminder: createReminder,
          voiceInput: SpeechToTextNusVoiceInput(),
        ),
      ),
    );
    if (mounted) {
      await _loadAppointments();
      setState(() {});
    }
  }

  Future<void> _openCopilot() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const AiHubPage(isArabic: true),
      ),
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const AboutNusPage(isArabic: true),
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsPage(isArabic: true),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    if (mounted) setState(() {});
  }

  Future<void> _removeReminder(legacy.ScheduleItem item) async {
    await widget.scheduleStore?.remove(item);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final todayAppointments = _appointmentItems
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => DateUtils.isSameDay(item.startsAt, today))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final nextAppointments = _appointmentItems
        .where((item) => item.status == AppointmentStatus.upcoming)
        .where((item) => item.startsAt.isAfter(now))
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'NUS Today',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'عن NUS',
              onPressed: _openAbout,
              icon: const Icon(Icons.info_outline_rounded),
            ),
            IconButton(
              tooltip: 'إعدادات التنبيهات',
              onPressed: _openNotificationSettings,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loadingAppointments || _loadingSpending
                  ? null
                  : () async {
                      await _loadAppointments();
                      await _loadSpending();
                      if (mounted) setState(() {});
                    },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadAppointments();
            await _loadSpending();
            if (mounted) setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
            children: [
              _heroCard(context, focusCount),
              const SizedBox(height: 12),
              _spendingSnapshot(),
              const SizedBox(height: 12),
              _dailyBriefing(insights),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      icon: Icons.add_task_rounded,
                      title: 'إضافة سريعة',
                      subtitle: 'اكتب أو اتكلم',
                      onTap: _openQuickAdd,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'NUS Copilot',
                      subtitle: 'اسأل NUS',
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
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'فلوسي',
                      subtitle: 'المال والالتزامات',
                      onTap: widget.onOpenFinance,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionCard(
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
                child: _remindersSection(todayReminders),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'مواعيد النهارده',
                icon: Icons.today_rounded,
                child: _appointmentsSection(todayAppointments),
              ),
              const SizedBox(height: 14),
              _section(
                title: 'الخطوة الجاية',
                icon: Icons.north_east_rounded,
                child: _nextAction(nextAppointments, upcomingReminders),
              ),
            ],
          ),
        ),
        floatingActionButton: widget.onCreateReminder == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _openQuickAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة'),
              ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, int focusCount) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              focusCount == 0
                  ? 'النهارده هادي. NUS جاهز لأي حاجة تدخل حياتك.'
                  : 'عندك $focusCount ${focusCount == 1 ? 'حاجة' : 'حاجات'} محتاجة انتباه النهارده.',
              style: TextStyle(
                height: 1.45,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.people_alt_outlined, '${widget.profile.householdSize} أفراد'),
                _chip(Icons.payments_outlined, _money(widget.profile.remainingAfterObligations)),
                _chip(Icons.flag_outlined, 'التزامات ${_money(widget.profile.recurringObligations)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير 👋';
    if (hour < 17) return 'مساء الخير ☀️';
    return 'مساء الخير 🌙';
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _spendingSnapshot() {
    final monthName = MaterialLocalizations.of(context).formatMonthYear(DateTime.now());
    if (widget.expenseManagementService == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('الوضع المالي', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('بيانات المال ستظهر بعد تفعيل مصدر المصروفات.'),
        ),
      );
    }
    if (_loadingSpending) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('الصرف الفعلي', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('NUS بيقرأ مصروفات الشهر…'),
        ),
      );
    }
    if (_spendingError != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: const Text('الصرف الفعلي', style: TextStyle(fontWeight: FontWeight.w900)),
          subtitle: const Text('تعذر قراءة المصروفات الآن.'),
          trailing: IconButton(
            onPressed: _loadSpending,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      );
    }

    final total = _monthlyActual ?? 0;
    final elapsedDays = DateTime.now().day;
    final averagePerDay = elapsedDays > 0 ? total ~/ elapsedDays : 0;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الصرف الفعلي — $monthName',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              _money(total),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text('متوسط مسجل حتى الآن: ${_money(averagePerDay)} يوميًا'),
          ],
        ),
      ),
    );
  }

  Widget _dailyBriefing(List<NusDailyInsight> insights) {
    return _section(
      title: 'ملخص صباحك',
      icon: Icons.auto_awesome_rounded,
      child: Column(
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
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(insight.message, style: const TextStyle(height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _remindersSection(List<legacy.ScheduleItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('مفيش تذكيرات للنهارده. أضف أول حاجة محتاج تفتكرها.'),
      );
    }
    return Column(
      children: [
        for (final item in items) _reminderTile(item),
      ],
    );
  }

  Widget _reminderTile(legacy.ScheduleItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: item.completed,
        onChanged: (_) => _toggleReminder(item),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          decoration: item.completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(TimeOfDay.fromDateTime(item.dateTime).format(context)),
      trailing: IconButton(
        tooltip: 'حذف',
        onPressed: () => _removeReminder(item),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    );
  }

  Widget _appointmentsSection(List<Appointment> items) {
    if (_loadingAppointments) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('مفيش مواعيد قادمة مسجلة النهارده.'),
      );
    }
    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_rounded),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(TimeOfDay.fromDateTime(item.startsAt).format(context)),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    );
  }

  Widget _nextAction(
    List<Appointment> appointments,
    List<legacy.ScheduleItem> reminders,
  ) {
    final appointment = appointments.isEmpty ? null : appointments.first;
    final reminder = reminders.isEmpty ? null : reminders.first;
    if (appointment == null && reminder == null) {
      return const Text('مفيش خطوة جاية واضحة. استخدم الإضافة السريعة ودخل الحاجة اللي في دماغك.');
    }

    final bool useReminder = reminder != null &&
        (appointment == null || reminder.dateTime.isBefore(appointment.startsAt));
    final String title;
    final DateTime when;
    if (useReminder) {
      title = reminder.title;
      when = reminder.dateTime;
    } else {
      title = appointment!.title;
      when = appointment.startsAt;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(useReminder ? Icons.check_rounded : Icons.event_available_rounded),
      ),
      title: Text(title.isEmpty ? 'مهمة بدون اسم' : title),
      subtitle: Text('اليوم ${TimeOfDay.fromDateTime(when).format(context)}'),
    );
  }
}
