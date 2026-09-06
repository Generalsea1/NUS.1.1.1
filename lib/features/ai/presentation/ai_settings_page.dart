import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, this.isArabic = true});

  final bool isArabic;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  String _provider = 'gemini';
  bool _loading = true;
  bool _connecting = false;
  bool _connected = false;
  String? _model;
  String? _error;

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadConnection();
  }

  Future<void> _loadConnection() async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final row = await client
          .from('user_ai_connections')
          .select('provider,status,model')
          .eq('user_id', client.auth.currentUser!.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        if (row is Map) {
          _provider = row['provider'] as String? ?? 'gemini';
          _connected = row['status'] == 'connected';
          _model = row['model'] as String?;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectGemini() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      setState(() => _error = _t(
            'Sign in to NUS before connecting an AI provider.',
            'سجّل دخولك في NUS الأول قبل ربط مزود الذكاء الاصطناعي.',
          ));
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      // Gemini user authorization is handled by the backend callback.
      // The app starts the OAuth flow using a short-lived state bound to the
      // authenticated NUS user and never stores provider secrets in Flutter.
      final response = await client.functions.invoke(
        'ai-provider-connect',
        body: {
          'provider': 'gemini',
          'action': 'start',
        },
      );
      final data = response.data;
      if (data is! Map || data['authorizationUrl'] is! String) {
        throw const _AiSettingsException('Authorization URL was not returned.');
      }
      final uri = Uri.tryParse(data['authorizationUrl'] as String);
      if (uri == null) {
        throw const _AiSettingsException('Invalid authorization URL.');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_t('Connect Gemini', 'ربط Gemini')),
          content: Text(_t(
            'Continue in the browser to authorize Gemini for your NUS account. Return to NUS after approval.',
            'كمّل في المتصفح للموافقة على ربط Gemini بحسابك في NUS، وبعد الموافقة ارجع للتطبيق.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t('Cancel', 'إلغاء')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openAuthorization(uri);
              },
              child: Text(_t('Continue', 'متابعة')),
            ),
          ],
        ),
      );
    } on FunctionException catch (error) {
      if (mounted) setState(() => _error = error.reasonPhrase ?? error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openAuthorization(Uri uri) async {
    // Keeping navigation behind a dedicated callback allows the actual mobile
    // deep-link implementation to be supplied without coupling this page to a
    // specific browser package.
    setState(() => _error = _t(
          'OAuth URL ready. Configure the NUS deep-link callback before production use.',
          'رابط OAuth جاهز. لازم إعداد Deep Link الخاص بـNUS قبل استخدامه في الإنتاج.',
        ));
  }

  Future<void> _disconnect() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    setState(() => _connecting = true);
    try {
      await client.from('user_ai_connections').update({
        'status': 'disconnected',
        'access_token_encrypted': null,
        'refresh_token_encrypted': null,
        'token_expires_at': null,
      }).eq('user_id', user.id).eq('provider', _provider);
      if (mounted) {
        setState(() {
          _connected = false;
          _model = null;
        });
      }
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

    return Scaffold(
      appBar: AppBar(title: Text(_t('AI', 'الذكاء الاصطناعي'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      _t('Your AI connections', 'اتصالات الذكاء الاصطناعي الخاصة بك'),
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Text(_t(
                    'Choose the provider you authorize. NUS never asks for your AI password and does not use a central AI key.',
                    'اختار مزود الذكاء الاصطناعي اللي إنت بتسمح له. NUS مش بيطلب كلمة مرور AI ومش بيعتمد على مفتاح AI مركزي.',
                  )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'gemini', label: Text('Google Gemini'), icon: const Icon(Icons.cloud_outlined)),
              ButtonSegment(value: 'openai', label: Text('OpenAI'), icon: const Icon(Icons.psychology_outlined)),
            ],
            selected: {_provider},
            onSelectionChanged: (value) => setState(() => _provider = value.first),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(_connected ? Icons.link_rounded : Icons.link_off_rounded),
              title: Text(_connected ? _t('Connected', 'متصل') : _t('Not connected', 'غير متصل')),
              subtitle: Text(_model ?? _t('No AI model selected yet.', 'لسه مفيش موديل AI متصل.')),
              trailing: _connected
                  ? OutlinedButton(
                      onPressed: _connecting ? null : _disconnect,
                      child: Text(_t('Disconnect', 'فصل')),
                    )
                  : FilledButton(
                      onPressed: _connecting || _provider != 'gemini' ? null : _connectGemini,
                      child: Text(_connecting ? _t('Connecting…', 'جاري الربط…') : _t('Connect', 'ربط')),
                    ),
            ),
          ),
          if (_provider == 'openai') ...[
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'OpenAI: Sign in with ChatGPT is an identity flow and does not grant NUS access to ChatGPT conversations or ChatGPT billing. OpenAI API access requires an explicitly supported authorization/billing path.',
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
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
