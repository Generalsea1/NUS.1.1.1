import 'package:flutter/material.dart';

import '../application/household_service.dart';
import '../data/supabase_household_repository.dart';
import '../domain/household.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({
    super.key,
    required this.userId,
    this.service,
  });

  final String userId;
  final HouseholdService? service;

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  late final HouseholdService _service =
      widget.service ?? HouseholdService(repository: const SupabaseHouseholdRepository());
  Household? _household;
  HouseholdMember? _membership;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final household = await _service.getOrCreateForUser(userId: widget.userId);
      final memberships = await _service.currentMemberships(widget.userId);
      HouseholdMember? membership;
      for (final item in memberships) {
        if (item.householdId == household.id) {
          membership = item;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _household = household;
        _membership = membership;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر فتح مساحة البيت الآن. لم يتم تغيير أي بيانات.';
      });
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'owner':
        return 'مالك البيت';
      case 'admin':
        return 'مدير';
      case 'member':
        return 'عضو';
      default:
        return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = _household;
    final membership = _membership;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('البيت والأسرة', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Column(
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 44),
                                const SizedBox(height: 10),
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const CircleAvatar(
                                  radius: 28,
                                  child: Icon(Icons.home_work_outlined, size: 30),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  household!.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'البيانات المشتركة هتتربط بالبيت ده تدريجيًا، مع احترام صلاحيات كل عضو.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                _InfoTile(
                                  icon: Icons.verified_user_outlined,
                                  title: 'دورك',
                                  value: _roleLabel(membership?.role),
                                ),
                                const SizedBox(height: 8),
                                _InfoTile(
                                  icon: Icons.shield_outlined,
                                  title: 'الحالة',
                                  value: membership?.isActive == true ? 'عضو نشط' : 'غير نشط',
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.lock_outline_rounded)),
                  title: Text('المشاركة تُبنى بصلاحيات واضحة'),
                  subtitle: Text('لا يوجد هنا أي كشف لمعلومات أعضاء آخرين أو كتابة تلقائية لبيانات مشتركة.'),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.construction_outlined)),
                  title: Text('الإدارة المتقدمة قيد البناء'),
                  subtitle: Text('الدعوات، الأدوار، وقوائم التسوق المشتركة ستُفتح بعد اكتمال طبقة الصلاحيات.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
