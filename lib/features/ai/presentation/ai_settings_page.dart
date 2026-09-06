import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/google_auth_repository.dart';
import '../../../core/supabase_service.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> with WidgetsBindingObserver {
  String _provider = 'gemini';
  bool _loading = true;
  bool _connecting = false;
  bool _signingIn = false;
  bool _connected = false;
  String? _model;
  String? _error;

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConnection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConnection();
    }
  }

  Future<void> _loadConnection() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _connected = false;
          _model = null;
        });
      }
      return;
    }
    try {
      final rows = await client
          .from('user_ai_connections')
          .select('provider,status,model')
          .eq('user_id', user.id)
          .order('provider');
      final row = (rows as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .firstWhere(
            (item) => item['provider'] == _provider,
            orElse: () => <String, dynamic>{},
          );
      if (!mounted) return;
      setState(() {
        _connected = row['status'] == 'connected';
        _model = row['model'] as String?;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _selectProvider(String provider) async {
    setState(() {
      _provider = provider;
      _connected = false;
      _model = null;
      _error = null;
    });
    await _loadConnection();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      final started = await const GoogleAuthRepository().signIn();
      if (!started && mounted) {
        setState(() {
          _error = _t(
            'Google sign-in is not configured for this NUS build.',
            'تسجيل دخول Google مش متظبط لنسخة NUS دي لسه.',
          );
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _connectGemini() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) {
        setState(() => _error = _t(
              'Sign in with Google before connecting your AI account.',
              'سجّل دخولك بحساب Google الأول قبل ربط حساب الذكاء الاصطناعي.',
            ));
      }
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final response = await client.functions.invoke(
        'ai-provider-connect',
        body: {'provider': 'gemini', 'action': 'start'},
      );
      final data = response.data;
      if (data is! Map || data['authorizationUrl'] is! String) {
        throw const _AiSettingsException('Authorization URL was not returned.');
      }
      final uri = Uri.tryParse(data['authorizationUrl'] as String);
      if (uri == null || !await canLaunchUrl(uri)) {
        throw const _AiSettingsException('The Google authorization link could not be opened.');
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw const _AiSettingsException('The Google authorization link could not be opened.');
      }
      if (mounted) {
        setState(() => _error = _t(
              'Choose the Google account you want to use for Gemini, approve access, then return to NUS.',
              'اختار حساب Google اللي عايز تستخدمه مع Gemini، وافق على الصلاحيات، وبعدها ارجع لـNUS.',
            ));
      }
    } on FunctionException catch (error) {
      if (mounted) setState(() => _error = error.reasonPhrase ?? error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await client.functions.invoke(
        'ai-provider-connect',
        body: {'provider': _provider, 'action': 'disconnect'},
      );
      if (mounted) {
        setState(() {
          _connected = false;
          _model = null;
        });
      }
    } on FunctionException catch (error) {
      if (mounted) setState(() => _error = error.reasonPhrase ?? error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = SupabaseService.client?.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('NUS AI', 'ذكاء NUS')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _AiHero(
            title: _t('Your personal intelligence layer', 'طبقة الذكاء الشخصية بتاعتك'),
            subtitle: _t(
              'Use your own authorized Google account. NUS does not ask for your Google or ChatGPT password.',
              'استخدم حساب Google بتاعك بعد التفويض. NUS مش بيطلب كلمة مرور Google أو ChatGPT منك.',
            ),
          ),
          const SizedBox(height: 14),
          if (user == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_circle_rounded, size: 54),
                    const SizedBox(height: 12),
                    Text(
                      _t('Sign in with your Google email', 'ادخل بحساب Google بتاعك'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'Google will show the account picker. Select the email you want NUS to associate with your account.',
                        'Google هيفتح لك اختيار الحساب. اختار الإيميل اللي عايز تربطه بحسابك في NUS.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _signingIn ? null : _signInWithGoogle,
                      icon: _signingIn
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        _signingIn
                            ? _t('Opening Google…', 'جاري فتح Google…')
                            : _t('Continue with Google', 'الدخول بحساب Google'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                title: Text(_t('NUS account', 'حساب NUS'), style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(user.email ?? _t('Google account', 'حساب Google')),
                trailing: const Icon(Icons.verified_rounded),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gemini', label: Text('Google Gemini'), icon: Icon(Icons.auto_awesome_rounded)),
                ButtonSegment(value: 'openai', label: Text('OpenAI'), icon: Icon(Icons.psychology_alt_rounded)),
              ],
              selected: {_provider},
              onSelectionChanged: (value) => _selectProvider(value.first),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(_connected ? Icons.link_rounded : Icons.link_off_rounded, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 9),
                      Expanded(child: Text(
                        _connected ? _t('Connected', 'متصل') : _t('Not connected', 'غير متصل'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      )),
                    ]),
                    const SizedBox(height: 7),
                    Text(_model ?? _t('No provider connection yet.', 'لسه مفيش مزود ذكاء متصل.')),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: _connected
                          ? OutlinedButton.icon(
                              onPressed: _connecting ? null : _disconnect,
                              icon: const Icon(Icons.link_off_rounded),
                              label: Text(_t('Disconnect Google AI', 'فصل Google AI')),
                            )
                          : FilledButton.icon(
                              onPressed: _connecting || _provider != 'gemini' ? null : _connectGemini,
                              icon: _connecting
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.account_balance_rounded),
                              label: Text(_connecting ? _t('Connecting…', 'جاري الربط…') : _t('Connect my Google Gemini account', 'اربط حساب Google Gemini')), 
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_t(
                  'OpenAI / ChatGPT is intentionally separate. A ChatGPT login does not grant NUS access to ChatGPT conversations, billing, or an API account. NUS will never ask for your ChatGPT password.',
                  'OpenAI / ChatGPT منفصل عمدًا. تسجيل دخول ChatGPT مش بيدي NUS صلاحية لمحادثات ChatGPT أو الفوترة أو حساب الـAPI. NUS عمره ما هيطلب باسورد ChatGPT.',
                )),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(padding: const EdgeInsets.all(14), child: Text(_error!)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiHero extends StatelessWidget {
  const _AiHero({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [scheme.primary, Color.alphaBlend(Colors.black.withValues(alpha: .15), scheme.primary)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .85), height: 1.45)),
        ],
      ),
    );
  }
}

class _AiSettingsException implements Exception {
  const _AiSettingsException(this.message);
  final String message;
  @override
  String toString() => message;
}
