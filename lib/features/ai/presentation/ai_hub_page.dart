import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/email_auth_repository.dart';
import '../../../core/supabase_service.dart';
import 'ai_history_page.dart';
import 'ai_settings_page.dart';

class AiHubPage extends StatefulWidget {
  const AiHubPage({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  State<AiHubPage> createState() => _AiHubPageState();
}

class _AiHubPageState extends State<AiHubPage> {
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final client = SupabaseService.client;
    _user = client?.auth.currentUser;
    _authSubscription = client?.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      setState(() => _user = state.session?.user);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0B776B), brightness: base.brightness);

    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: dark ? const Color(0xFF081310) : const Color(0xFFF5F2EA),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: dark ? const Color(0xFF12201C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('NUS account & AI', 'حساب NUS والذكاء الاصطناعي'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              children: [
                _heroCard(context),
                const SizedBox(height: 12),
                if (_user == null) _AuthCard(isArabic: widget.isArabic) else _accountCard(context, _user!),
                const SizedBox(height: 12),
                _securityCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('Your household intelligence', 'ذكاء البيت بتاعك'), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 5),
                  Text(_t('Create one NUS account. Then the household manager can use your saved profile and AI services.', 'اعمل حساب NUS مرة واحدة. بعدها مدير البيت يقدر يستخدم ملفك المحفوظ وخدمات الذكاء الاصطناعي.'), style: TextStyle(color: scheme.onPrimaryContainer, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context, User user) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: scheme.primaryContainer, foregroundColor: scheme.onPrimaryContainer, child: const Icon(Icons.person_rounded)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.email ?? _t('NUS account', 'حساب NUS'), style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(_t('Signed in successfully.', 'تم تسجيل الدخول بنجاح.'), style: TextStyle(color: scheme.onSurfaceVariant))])),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: scheme.tertiaryContainer,
          child: ListTile(
            leading: const Icon(Icons.verified_rounded),
            title: Text(_t('Account ready', 'الحساب جاهز'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(_t('You can now save the household profile and use AI features that require a NUS account.', 'تقدر دلوقتي تحفظ بيانات البيت وتستخدم مزايا الذكاء اللي محتاجة حساب NUS.')),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: widget.isArabic))),
          icon: const Icon(Icons.link_rounded),
          label: Text(_t('AI connection settings', 'إعدادات اتصال الذكاء الاصطناعي')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiHistoryPage(isArabic: widget.isArabic))),
          icon: const Icon(Icons.history_rounded),
          label: Text(_t('My AI history', 'سجل تحليلاتي')),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            final client = SupabaseService.client;
            await client?.auth.signOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: Text(_t('Sign out', 'تسجيل الخروج')),
        ),
      ],
    );
  }

  Widget _securityCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _t(
                  'Your NUS account password is only handled by Supabase Auth. AI provider authorization is separate, and NUS never asks for a Google or ChatGPT password.',
                  'كلمة مرور حساب NUS بتتعامل معاها Supabase Auth فقط. تفويض مزود الذكاء منفصل، وNUS عمره ما يطلب باسورد Google أو ChatGPT.',
                ),
                style: TextStyle(color: scheme.onSecondaryContainer, height: 1.45, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCard extends StatefulWidget {
  const _AuthCard({required this.isArabic});

  final bool isArabic;

  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = true;
  bool _busy = false;
  bool _obscure = true;
  String? _message;
  bool _error = false;

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@')) {
      _setError(_t('Enter a valid email address.', 'اكتب بريد إلكتروني صحيح.'));
      return;
    }
    if (_createAccount && password.length < 6) {
      _setError(_t('Use a password with at least 6 characters.', 'استخدم كلمة مرور لا تقل عن 6 أحرف.'));
      return;
    }
    if (!_createAccount && password.isEmpty) {
      _setError(_t('Enter your password.', 'اكتب كلمة المرور.'));
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });

    try {
      final repository = const EmailAuthRepository();
      final response = _createAccount
          ? await repository.signUp(email: email, password: password)
          : await repository.signIn(email: email, password: password);

      if (!mounted) return;
      setState(() {
        _error = false;
        _message = _createAccount
            ? (response.session == null
                ? _t('Account created. Check your email, then sign in.', 'تم إنشاء الحساب. راجع بريدك الإلكتروني، وبعدها سجّل الدخول.')
                : _t('Account created and signed in.', 'تم إنشاء الحساب وتسجيل الدخول.'))
            : _t('Signed in successfully.', 'تم تسجيل الدخول بنجاح.');
      });
      FocusScope.of(context).unfocus();
    } on AuthException catch (error) {
      final raw = error.message.toLowerCase();
      final friendly = raw.contains('invalid login credentials')
          ? _t('The email or password is incorrect.', 'البريد الإلكتروني أو كلمة المرور غير صحيحة.')
          : raw.contains('email not confirmed')
              ? _t('Confirm your email first, then sign in again.', 'فعّل بريدك الإلكتروني الأول ثم سجّل الدخول مرة تانية.')
              : _createAccount
                  ? _t('Account creation failed: ${error.message}', 'فشل إنشاء الحساب: ${error.message}')
                  : _t('Login failed: ${error.message}', 'فشل تسجيل الدخول: ${error.message}');
      _setError(friendly);
    } on EmailAuthConfigurationException catch (error) {
      _setError(error.toString());
    } catch (_) {
      _setError(_createAccount ? _t('Could not create the account right now.', 'تعذر إنشاء الحساب حاليًا.') : _t('Could not complete login right now.', 'تعذر إكمال تسجيل الدخول حاليًا.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = true;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_createAccount ? _t('Create your NUS account', 'اعمل حساب NUS') : _t('Welcome back', 'أهلًا بيك تاني'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(_createAccount ? _t('Your account lets the household manager save your real profile securely.', 'الحساب بيسمح لمدير البيت يحفظ ملفك الحقيقي بأمان.') : _t('Use the same email and password you created for NUS.', 'استخدم نفس البريد وكلمة المرور اللي عملت بيهم حساب NUS.')),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(_t('Create account', 'إنشاء حساب')), icon: const Icon(Icons.person_add_alt_1_rounded)),
                ButtonSegment(value: false, label: Text(_t('Sign in', 'دخول')), icon: const Icon(Icons.login_rounded)),
              ],
              selected: {_createAccount},
              onSelectionChanged: _busy ? null : (selection) => setState(() { _createAccount = selection.first; _message = null; _error = false; }),
            ),
            const SizedBox(height: 14),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: _t('Email', 'البريد الإلكتروني'), prefixIcon: const Icon(Icons.email_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _password, obscureText: _obscure, onSubmitted: (_) => _busy ? null : _submit(), autofillHints: _createAccount ? const [AutofillHints.newPassword] : const [AutofillHints.password], decoration: InputDecoration(labelText: _t('Password', 'كلمة المرور'), prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: _busy ? null : _submit, icon: _busy ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_createAccount ? Icons.person_add_alt_1_rounded : Icons.login_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_busy ? _t('Please wait…', 'استنى لحظة…') : (_createAccount ? _t('Create account', 'إنشاء الحساب') : _t('Sign in', 'تسجيل الدخول')), style: const TextStyle(fontWeight: FontWeight.w900)))),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: (_error ? scheme.errorContainer : scheme.tertiaryContainer), borderRadius: BorderRadius.circular(14)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(_error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded), const SizedBox(width: 8), Expanded(child: Text(_message!, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)))]),
              ),
            ],
            const SizedBox(height: 12),
            Text(_t('Google sign-in is intentionally not shown here because the current project has Google OAuth disabled. Email/password is the NUS account path.', 'تسجيل Google مش ظاهر هنا عمدًا لأن مشروع NUS الحالي Google OAuth فيه غير مفعّل. المسار الأساسي لحساب NUS هو البريد وكلمة المرور.'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
