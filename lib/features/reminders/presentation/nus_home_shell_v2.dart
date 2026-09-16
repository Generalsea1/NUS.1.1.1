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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
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
