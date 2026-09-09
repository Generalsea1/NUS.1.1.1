import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/household_invitation_service.dart';
import '../application/household_service.dart';
import '../data/supabase_household_invitation_repository.dart';
import '../data/supabase_household_repository.dart';
import '../domain/household.dart';
import '../domain/household_invitation.dart';

class HouseholdMembersPage extends StatefulWidget {
  const HouseholdMembersPage({
    super.key,
    required this.household,
    required this.currentMembership,
    this.householdService,
    this.invitationService,
  });

  final Household household;
  final HouseholdMember currentMembership;
  final HouseholdService? householdService;
  final HouseholdInvitationService? invitationService;

  @override
  State<HouseholdMembersPage> createState() => _HouseholdMembersPageState();
}

class _HouseholdMembersPageState extends State<HouseholdMembersPage> {
  late final HouseholdService _householdService =
      widget.householdService ?? HouseholdService(repository: const SupabaseHouseholdRepository());
  late final HouseholdInvitationService _invitationService =
      widget.invitationService ??
          HouseholdInvitationService(repository: const SupabaseHouseholdInvitationRepository());

  List<HouseholdMember> _members = const [];
  List<HouseholdInvitation> _invitations = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canManage => widget.currentMembership.canManage;

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
      final members = await _householdService.householdMembers(widget.household.id);
      final invitations = _canManage
          ? await _invitationService.list(householdId: widget.household.id)
          : const <HouseholdInvitation>[];
      if (!mounted) return;
      setState(() {
        _members = members;
        _invitations = invitations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل أعضاء البيت الآن.';
      });
    }
  }

  Future<void> _invite() async {
    if (!_canManage || _saving) return;
    final emailController = TextEditingController();
    try {
      final email = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('دعوة عضو للبيت'),
          content: TextField(
            controller: emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              hintText: 'family@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(emailController.text.trim()),
              child: const Text('إنشاء دعوة'),
            ),
          ],
        ),
      );
      if (!mounted || email == null || email.isEmpty) return;

      setState(() => _saving = true);
      final created = await _invitationService.create(
        householdId: widget.household.id,
        invitedEmail: email,
        createdBy: widget.currentMembership.userId,
      );
      if (!mounted) return;
      await _showCreatedToken(created);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إنشاء الدعوة. راجع البريد أو صلاحيتك داخل البيت.')),
        );
      }
    } finally {
      emailController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCreatedToken(CreatedHouseholdInvitation created) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الدعوة جاهزة'),
        content: SelectableText(
          'ابعت الكود ده للشخص المدعو. الكود مرتبط بالبريد المدعو ويُستخدم مرة واحدة.\n\n${created.token}',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: created.token));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ كود الدعوة.')),
                );
              }
            },
            child: const Text('نسخ الكود'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptInvitation() async {
    if (_saving) return;
    final tokenController = TextEditingController();
    try {
      final token = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('الانضمام بكود دعوة'),
          content: TextField(
            controller: tokenController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'كود الدعوة'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(tokenController.text.trim()),
              child: const Text('انضمام'),
            ),
          ],
        ),
      );
      if (!mounted || token == null || token.isEmpty) return;
      setState(() => _saving = true);
      await _invitationService.accept(token: token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الدعوة. أعد فتح مساحة البيت لتظهر العضوية الجديدة.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قبول الدعوة. تأكد من الكود والبريد المستخدم للحساب.')),
        );
      }
    } finally {
      tokenController.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(HouseholdInvitation invitation) async {
    if (!_canManage || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الدعوة؟'),
        content: Text('سيتم إلغاء دعوة ${invitation.invitedEmail} الحالية.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('إلغاء الدعوة')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _saving = true);
    try {
      await _invitationService.revoke(
        invitationId: invitation.id,
        householdId: widget.household.id,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إلغاء الدعوة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'مالك';
      case 'admin':
        return 'مدير';
      default:
        return 'عضو';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('أعضاء البيت', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      if (_error != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 10),
                                FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.people_outline_rounded)),
                            title: Text('${_members.length} أعضاء نشطين', style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: const Text('البيت يرى فقط العضوية والصلاحيات، بدون عرض البريد أو بيانات تعريفية غير لازمة.'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final member in _members)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(member.role == 'owner' ? Icons.star_outline_rounded : Icons.person_outline_rounded)),
                              title: Text(member.userId == widget.currentMembership.userId ? 'أنت' : 'عضو البيت'),
                              subtitle: const Text('عضو نشط'),
                              trailing: Text(_roleLabel(member.role), style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ),
                        if (_canManage) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const ValueKey<String>('household-invite-member'),
                            onPressed: _saving ? null : _invite,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('دعوة عضو'),
                          ),
                          const SizedBox(height: 12),
                          if (_invitations.where((item) => item.isPending).isNotEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('الدعوات الحالية', style: TextStyle(fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 8),
                                    for (final invitation in _invitations.where((item) => item.isPending))
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.mark_email_unread_outlined),
                                        title: Text(invitation.invitedEmail),
                                        subtitle: Text('تنتهي ${MaterialLocalizations.of(context).formatFullDate(invitation.expiresAt.toLocal())}'),
                                        trailing: IconButton(
                                          tooltip: 'إلغاء',
                                          onPressed: _saving ? null : () => _revoke(invitation),
                                          icon: const Icon(Icons.cancel_outlined),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const ValueKey<String>('household-accept-invitation'),
                          onPressed: _saving ? null : _acceptInvitation,
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('الانضمام إلى بيت بكود دعوة'),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
