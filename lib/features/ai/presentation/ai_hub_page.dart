import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/email_auth_repository.dart';
import '../../../core/auth/google_auth_repository.dart';
import '../../../core/supabase_service.dart';
import 'ai_history_page.dart';
import 'ai_settings_page.dart';

class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key, this.isArabic = true});
  final bool isArabic;

  String _t(String en, String ar) => isArabic ? ar : en;

  ColorScheme _scheme(BuildContext context) => ColorScheme.fromSeed(
        seedColor: const Color(0xFF0F5B55),
        brightness: Theme.of(context).brightness,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme(context);
    final user = SupabaseService.client?.auth.currentUser;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0E1514)
            : const Color(0xFFF7F5EF),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF17201E)
              : Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('AI manager', 'مدير الذكاء الاصطناعي')),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            _headerCard(context),
            const SizedBox(height: 14),
            if (user == null)
              _LoginCard(isArabic: isArabic)
            else ...[
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.person_rounded),
                  ),
                  title: Text(user.email ?? _t('NUS account', 'حساب NUS')),
                  subtitle: Text(_t('Authenticated NUS account', 'حساب NUS موثّق')),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: isArabic)),
                ),
                icon: const Icon(Icons.link_rounded),
                label: Text(_t('AI provider connections', 'اتصالات مزودي الذكاء الاصطناعي')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AiHistoryPage(isArabic: isArabic)),
                ),
                icon: const Icon(Icons.history_rounded),
                label: Text(_t('My AI history', 'سجل تحليلاتي بالذكاء الاصطناعي')),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _t(
                          'Your NUS login is separate from Gemini authorization. NUS never asks for your Google password.',
                          'تسجيل دخول NUS منفصل عن تفويض Gemini. NUS عمره ما يطلب باسورد Google.',
                        ),
                        style: TextStyle(
                          color: scheme.onSecondaryContainer,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _headerCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, const Color(0xFFC8A96A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Your personal intelligence layer', 'طبقة الذكاء الشخصية بتاعتك'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t(
                      'Real household planning starts after you authenticate and authorize the AI provider.',
                      'التخطيط الحقيقي للبيت يبدأ بعد تسجيل دخولك وتفويض مزود الذكاء الاصطناعي.',
                    ),
                    style: TextStyle(color: scheme.onPrimaryContainer, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatefulWidget {
  const _LoginCard({required this.isArabic});
  final bool isArabic;

  @override
  State<_LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<_LoginCard> {
  final _email = TextEditingController();
  final _password = TextEditingController();
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

  Future<void> _emailSignIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.isEmpty) {
      setState(() {
        _error = true;
        _message = _t('Enter a valid email and password.', 'اكتب بريد إلكتروني صحيح وكلمة مرور.');
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });

    try {
      await const EmailAuthRepository().signIn(
        email: email,
        password: password,
      );
      if (mounted) setState(() => _message = _t('Signed in successfully.', 'تم تسجيل الدخول بنجاح.'));
      if (mounted) setState(() {});
    } on AuthException catch (error) {
      final raw = error.message.toLowerCase();
      final message = raw.contains('invalid login credentials')
          ? _t('The email or password is incorrect.', 'البريد الإلكتروني أو كلمة المرور غير صحيحة.')
          : raw.contains('email not confirmed')
              ? _t('Confirm your email first, then sign in again.', 'فعّل بريدك الإلكتروني أولًا ثم سجّل الدخول مرة تانية.')
              : _t('Login failed. Please try again.', 'فشل تسجيل الدخول. حاول مرة تانية.');
      if (mounted) {
        setState(() {
          _error = true;
          _message = message;
        });
      }
    } on EmailAuthConfigurationException catch (error) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = error.toString();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _t('Could not complete login right now.', 'تعذر إكمال تسجيل الدخول حاليًا.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailSignUp() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || password.length < 6) {
      setState(() {
        _error = true;
        _message = _t(
          'Use a valid email and a password with at least 6 characters.',
          'استخدم بريد صحيح وكلمة مرور لا تقل عن 6 أحرف.',
        );
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });

    try {
      final response = await const EmailAuthRepository().signUp(
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _error = false;
        _message = response.session == null
            ? _t(
                'Account created. Confirm your email, then sign in.',
                'تم إنشاء الحساب. فعّل بريدك الإلكتروني ثم سجّل الدخول.',
              )
            : _t('Account created and signed in.', 'تم إنشاء الحساب وتسجيل الدخول.');
      });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _t('Account creation failed.', 'فشل إنشاء الحساب.');
        });
      }
      debugPrint('NUS email sign-up: ${error.message}');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _t('Could not create the account right now.', 'تعذر إنشاء الحساب حاليًا.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final started = await const GoogleAuthRepository().signIn();
      if (!started && mounted) {
        setState(() {
          _error = true;
          _message = _t('Google sign-in is not configured for this build.', 'تسجيل دخول Google مش متظبط للنسخة دي.');
        });
      }
    } on GoogleProviderDisabledException catch (error) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = error.message(widget.isArabic);
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _t('Google sign-in failed: ${error.message}', 'فشل تسجيل الدخول بجوجل: ${error.message}');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = _t('Could not start Google sign-in right now.', 'تعذر بدء تسجيل الدخول بجوجل حاليًا.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _t('Sign in to NUS', 'تسجيل الدخول إلى NUS'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(_t('Use email/password or Google. Gemini is authorized separately.', 'استخدم البريد وكلمة المرور أو Google. تفويض Gemini بيتم بشكل منفصل.')),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: InputDecoration(
                labelText: _t('Email', 'البريد الإلكتروني'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: _obscure,
              onSubmitted: (_) => _busy ? null : _emailSignIn(),
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: _t('Password', 'كلمة المرور'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _emailSignIn,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login_rounded),
              label: Text(_t('Sign in with email', 'تسجيل الدخول بالبريد')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _emailSignUp,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(_t('Create NUS account', 'إنشاء حساب NUS')),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _googleSignIn,
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(_t('Continue with Google', 'الدخول بحساب Google')),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _error ? scheme.errorContainer : scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _error ? scheme.onErrorContainer : scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
