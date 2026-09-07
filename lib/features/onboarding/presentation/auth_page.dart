import 'package:flutter/material.dart';

import '../../../core/auth/email_auth_repository.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.emailAuthRepository = const EmailAuthRepository(),
  });

  final EmailAuthRepository emailAuthRepository;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _registering = true;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_registering) {
        final response = await widget.emailAuthRepository.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (response.session == null && mounted) {
          setState(() {
            _message =
                'تم إنشاء الحساب. افتح رسالة التأكيد في بريدك ثم سجّل الدخول.';
            _registering = false;
          });
        }
      } else {
        await widget.emailAuthRepository.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (text.contains('User already registered')) {
      return 'هذا البريد مسجّل بالفعل. استخدم تسجيل الدخول.';
    }
    if (text.contains('email')) {
      return text;
    }
    return 'تعذر إتمام العملية الآن. راجع الاتصال والإعدادات ثم حاول مرة أخرى.';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'اكتب البريد الإلكتروني.';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'اكتب بريدًا إلكترونيًا صحيحًا.';
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'NUS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'مدير الاقتصاد الذكي للمنزل',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registering
                              ? 'أنشئ حسابك، ثم سنجهّز معك الملف المالي الحقيقي للبيت.'
                              : 'سجّل الدخول للعودة إلى حالتك المالية المحفوظة.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        if (_registering) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              prefixIcon: Icon(Icons.lock_reset_outlined),
                            ),
                            validator: (value) => value != _passwordController.text
                                ? 'تأكيد كلمة المرور غير مطابق.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_message != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_registering ? 'إنشاء الحساب' : 'تسجيل الدخول'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _registering = !_registering;
                                    _message = null;
                                    _confirmController.clear();
                                  }),
                          child: Text(_registering
                              ? 'لديك حساب بالفعل؟ تسجيل الدخول'
                              : 'مستخدم جديد؟ إنشاء حساب'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'تسجيل Google موجود في البنية الحالية، لكنه لا يُشغَّل تلقائيًا أثناء الدخول حتى لا يحجب إعداد OAuth شاشة البداية.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
