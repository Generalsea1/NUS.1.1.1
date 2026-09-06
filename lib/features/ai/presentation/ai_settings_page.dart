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

class _AiSettingsPageState extends State<AiSettingsPage>
    with WidgetsBindingObserver {
  String _provider = 'gemini';
  bool _loading = true;
  bool _connecting = false;
  bool _signingIn = false;
  bool _connected = false;
  String? _model;
  String? _statusMessage;
  bool _statusIsError = false;

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
          _statusIsError = true;
          _statusMessage = error.toString();
        });
      }
    }
  }

  Future<void> _selectProvider(String provider) async {
    setState(() {
      _provider = provider;
      _connected = false;
      _model = null;
      _statusMessage = null;
      _statusIsError = false;
    });
    await _loadConnection();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      final started = await const GoogleAuthRepository().signIn();
      if (!started && mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = _t(
            'Google sign-in is not configured for this NUS build.',
            'تسجيل دخول Google مش متظبط لنسخة NUS دي لسه.',
          );
        });
      } else if (mounted) {
        setState(() {
          _statusMessage = _t(
            'Continue in Google, then return to NUS. Your account will be detected automatically.',
            'كمّل الدخول من Google وبعدها ارجع لـNUS. الحساب هيتعرف تلقائيًا.',
          );
          _statusIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _connectGemini() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = _t(
            'Sign in with your Google account to NUS first.',
            'سجّل دخولك بحساب Google في NUS الأول.',
          );
        });
      }
      return;
    }

    setState(() {
      _connecting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      final response = await client.functions.invoke(
        'ai-provider-connect',
        body: {'provider': 'gemini', 'action': 'start'},
      );
      final data = response.data;
      if (data is! Map || data['authorizationUrl'] is! String) {
        throw const _AiSettingsException(
          'The Gemini authorization URL was not returned.',
        );
      }

      final uri = Uri.tryParse(data['authorizationUrl'] as String);
      if (uri == null || !await canLaunchUrl(uri)) {
        throw const _AiSettingsException(
          'The Gemini authorization link could not be opened.',
        );
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const _AiSettingsException(
          'The Gemini authorization link could not be opened.',
        );
      }

      if (mounted) {
        setState(() {
          _statusIsError = false;
          _statusMessage = _t(
            'Approve Gemini access in Google. After you return to NUS, the connection will refresh automatically.',
            'وافق على صلاحية Gemini من Google. وبعد الرجوع لـNUS حالة الاتصال هتتحدث تلقائيًا.',
          );
        });
      }
    } on FunctionException catch (error) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = error.reasonPhrase ?? error.toString();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = error.toString();
        });
      }
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
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      await client.from('user_ai_connections').update({
        'status': 'disconnected',
        'access_token_encrypted': null,
        'refresh_token_encrypted': null,
        'token_expires_at': null,
        'last_error': null,
      }).eq('user_id', user.id).eq('provider', _provider);

      if (mounted) {
        setState(() {
          _connected = false;
          _model = null;
          _statusMessage = _t(
            'Gemini is disconnected. NUS will not use it for AI planning.',
            'تم فصل Gemini. NUS مش هيستخدمه في التخطيط بالذكاء الاصطناعي.',
          );
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusIsError = true;
          _statusMessage = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Widget _statusCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = _connected;
    return Card(
      elevation: 0,
      color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: active ? scheme.primary : scheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                active ? Icons.auto_awesome_rounded : Icons.link_off_rounded,
                color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? _t('AI is ready', 'الذكاء الاصطناعي جاهز')
                        : _t('AI is not connected', 'الذكاء الاصطناعي غير متصل'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    active
                        ? (_model ?? 'Google Gemini')
                        : _t(
                            'No recommendation will be invented while Gemini is unavailable.',
                            'مش هنخترع أي توصية مالية طالما Gemini مش متاح.',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = SupabaseService.client?.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('AI Center', 'مركز الذكاء الاصطناعي'))),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3949AB), Color(0xFF7C4DFF)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _t('Your personal AI manager', 'مديرك الشخصي بالذكاء الاصطناعي'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        _t(
                          'Sign in with the Google account you use for NUS. Then authorize Gemini separately for real AI household planning.',
                          'سجّل بالحساب اللي بتستخدمه مع Google، وبعدها فوّض Gemini بشكل منفصل عشان التخطيط المالي يكون حقيقي.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _signingIn ? null : _signInWithGoogle,
                          icon: _signingIn
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _signingIn
                                  ? _t('Opening Google…', 'جاري فتح Google…')
                                  : _t('Continue with Google', 'الدخول بحساب Google'),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(_t('Account ownership', 'ملكية الحساب')),
                  subtitle: Text(_t(
                    'Your NUS identity and AI connections are stored under your authenticated account.',
                    'حساب NUS واتصالات الذكاء الاصطناعي بيتسجلوا تحت حسابك الموثّق.',
                  )),
                ),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                _messageCard(context),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('AI Center', 'مركز الذكاء الاصطناعي')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 27,
                      child: Icon(Icons.account_circle_outlined, size: 31),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email ?? _t('Google account', 'حساب Google'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(_t('Authenticated NUS account', 'حساب NUS موثّق')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _statusCard(context),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'gemini',
                  label: const Text('Google Gemini'),
                  icon: const Icon(Icons.cloud_outlined),
                ),
                ButtonSegment(
                  value: 'openai',
                  label: const Text('OpenAI'),
                  icon: const Icon(Icons.psychology_outlined),
                ),
              ],
              selected: {_provider},
              onSelectionChanged: (value) => _selectProvider(value.first),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _provider == 'gemini'
                          ? _t('Google Gemini', 'Google Gemini')
                          : _t('OpenAI', 'OpenAI'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _provider == 'gemini'
                          ? _t(
                              'NUS uses Gemini only after you explicitly authorize your Google account. Your Google password is never entered into NUS.',
                              'NUS بيستخدم Gemini فقط بعد ما تفوّض حساب Google بنفسك. باسورد Google مش بيتكتب في NUS.',
                            )
                          : _t(
                              'OpenAI remains disabled until a supported user-authorization flow is implemented. NUS will never ask for a ChatGPT password.',
                              'OpenAI لسه مقفول لحد ما طريقة التفويض الرسمية للمستخدم تكتمل. NUS عمره ما هيطلب باسورد ChatGPT.',
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: _connected && _provider == 'gemini'
                          ? OutlinedButton.icon(
                              onPressed: _connecting ? null : _disconnect,
                              icon: const Icon(Icons.link_off_rounded),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(_t('Disconnect Gemini', 'فصل Gemini')),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: _connecting || _provider != 'gemini'
                                  ? null
                                  : _connectGemini,
                              icon: _connecting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.link_rounded),
                              label: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  _connecting
                                      ? _t('Connecting…', 'جاري الربط…')
                                      : _t('Connect Google Gemini', 'ربط Google Gemini'),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_t(
                        'NUS must never invent a financial recommendation when the real AI service is unavailable.',
                        'NUS ممنوع يخترع توصية مالية لما خدمة الذكاء الاصطناعي الحقيقية تكون غير متاحة.',
                      )),
                    ),
                  ],
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              _messageCard(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: _statusIsError ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _statusIsError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _statusMessage!,
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
              ),
            ),
          ],
        ),
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
