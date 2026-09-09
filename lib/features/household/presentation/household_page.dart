import 'package:flutter/material.dart';

import '../application/household_service.dart';
import '../data/supabase_household_repository.dart';
import '../domain/household.dart';
import 'household_members_page.dart';
import '../../ai/presentation/nus_copilot_page.dart';
import '../../shopping/application/shopping_lifecycle_service.dart';
import '../../shopping/data/supabase_household_shopping_repository.dart';
import '../../shopping/presentation/shopping_page.dart';

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

  void _openSharedShopping(Household household) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShoppingPage(
          service: ShoppingLifecycleService(
            repository: SupabaseHouseholdShoppingRepository(
              householdId: household.id,
            ),
          ),
          isArabic: true,
        ),
      ),
    );
  }

  void _openMembers(Household household, HouseholdMember membership) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HouseholdMembersPage(
          household: household,
          currentMembership: membership,
        ),
      ),
    );
  }

  void _openCopilot() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NusCopilotPage()),
    );
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
                                  'مساحة مشتركة للبيت، مع فصل واضح بين البيانات الشخصية والصلاحيات المشتركة.',
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
              if (household != null && membership?.isActive == true) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                    title: const Text('NUS Copilot', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('اسأل NUS عن يومك وبيتك باستخدام سياق محدود من المال والمواعيد والمشتريات.'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: _openCopilot,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.people_outline_rounded)),
                    title: const Text('أعضاء البيت', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('عرض العضوية والأدوار ودعوة أفراد جدد بصلاحيات واضحة.'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => _openMembers(household, membership!),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.shopping_cart_outlined)),
                    title: const Text('مشتريات البيت المشتركة', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('قائمة واحدة للبيت كله، وكل عضو نشط يقدر يضيف ويعلّم العناصر كمكتملة.'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => _openSharedShopping(household),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.lock_outline_rounded)),
                  title: Text('الخصوصية أولوية'),
                  subtitle: Text('البيت يرى بيانات المشاركة المطلوبة فقط، ولا يكشف البريد أو التفاصيل المالية الشخصية تلقائيًا.'),
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
