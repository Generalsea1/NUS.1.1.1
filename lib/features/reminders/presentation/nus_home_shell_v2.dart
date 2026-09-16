import 'package:flutter/material.dart';

import '../../../legacy_main.dart';
import '../../finance/presentation/nus_ai_command_page.dart';
import '../../finance/presentation/nus_financial_home_page.dart';
import '../../medications/application/medication_lifecycle_service.dart';
import 'reminders_hub_page.dart';

class NusHomeShellV2 extends StatefulWidget {
  const NusHomeShellV2({
    super.key,
    required this.profile,
    required this.expenseManagementService,
    required this.scheduleStore,
    required this.medicationService,
    required this.onSignOut,
  });

  final dynamic profile;
  final dynamic expenseManagementService;
  final ScheduleStore scheduleStore;
  final MedicationLifecycleService medicationService;
  final VoidCallback onSignOut;

  @override
  State<NusHomeShellV2> createState() => _NusHomeShellV2State();
}

class _NusHomeShellV2State extends State<NusHomeShellV2> {
  int _index = 0;

  void _showHomeQuickAccess() {
    if (_index != 0) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('الوصول السريع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.notifications_active_rounded)),
                title: const Text('مواعيدي وتذكيراتي', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('المواعيد، الأدوية، والتذكيرات اليومية.'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _index = 1);
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                title: const Text('NUS الذكي', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: const Text('اسأل المستشار الذكي عن وضع بيتك المالي.'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => _index = 2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            if (_index == 0)
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: SizedBox(
                  height: 54,
                  child: Row(
                    children: <Widget>[
                      const SizedBox(width: 12),
                      const Icon(Icons.home_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('مركز البيت — كل أدوات NUS في متناولك', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      TextButton.icon(
                        onPressed: _showHomeQuickAccess,
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: const Text('الأدوات'),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: <Widget>[
                  NusFinancialHomePage(
                    profile: widget.profile,
                    expenseManagementService: widget.expenseManagementService,
                    onSignOut: widget.onSignOut,
                  ),
                  RemindersHubPage(
                    scheduleStore: widget.scheduleStore,
                    medicationService: widget.medicationService,
                  ),
                  NusAiCommandPage(
                    profile: widget.profile,
                    expenseManagementService: widget.expenseManagementService,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            if (!mounted) return;
            setState(() => _index = value);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'البيت',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_active_rounded),
              label: 'مواعيدي وتذكيراتي',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'NUS الذكي',
            ),
          ],
        ),
      ),
    );
  }
}
