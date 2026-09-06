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
    if (state == AppLifecycleState.resumed) _loadConnection();
  }

  Future<void> _loadConnection() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) setState(() { _loading = false; _connected = false; _model = null; });
      return;
    }
    try {
      final rows = await client.from('user_ai_connections').select('provider,status,model').eq('user_id', user.id).order('provider');
      final row = (rows as List).whereType<Map>().map((item) => Map<String,dynamic>.from(item)).firstWhere((item) => item['provider'] == _provider, orElse: () => <String,dynamic>{});
      if (mounted) setState(() { _connected = row['status'] == 'connected'; _model = row['model'] as String?; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = error.toString(); });
    }
  }

  Future<void> _selectProvider(String provider) async {
    setState(() { _provider = provider; _connected = false; _model = null; _error = null; });
    await _loadConnection();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _signingIn = true; _error = null; });
    try {
      final started = await const GoogleAuthRepository().signIn();
      if (!started && mounted) setState(() => _error = _t('Google sign-in is not configured for this NUS build.', 'تسجيل دخول Google مش متظبط لنسخة NUS دي لسه.'));
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _signingIn = false); }
  }

  Future<void> _connectGemini() async {
    final client = SupabaseService.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      if (mounted) setState(() => _error = _t('Sign in to NUS before connecting an AI provider.', 'سجّل دخولك في NUS الأول قبل ربط مزود الذكاء الاصطناعي.'));
      return;
    }
    setState(() { _connecting = true; _error = null; });
    try {
      final response = await client.functions.invoke('ai-provider-connect', body: {'provider':'gemini','action':'start'});
      final data = response.data;
      if (data is! Map || data['authorizationUrl'] is! String) throw const _AiSettingsException('Authorization URL was not returned.');
      final uri = Uri.tryParse(data['authorizationUrl'] as String);
      if (uri == null || !await canLaunchUrl(uri)) throw const _AiSettingsException('The Gemini authorization link could not be opened.');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) throw const _AiSettingsException('The Gemini authorization link could not be opened.');
      if (mounted) setState(() => _error = _t('Approve access in Google, then return to NUS. The connection status will refresh automatically.', 'وافق على الوصول في Google وبعدها ارجع لـNUS. حالة الاتصال هتتحدث تلقائيًا.'));
    } on FunctionException catch (error) { if (mounted) setState(() => _error = error.reasonPhrase ?? error.toString()); }
    catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _connecting = false); }
  }

  Future<void> _disconnect() async {
    final client = SupabaseService.client; final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    setState(() { _connecting = true; _error = null; });
    try {
      await client.from('user_ai_connections').update({'status':'disconnected','access_token_encrypted':null,'refresh_token_encrypted':null,'token_expires_at':null,'last_error':null}).eq('user_id', user.id).eq('provider', _provider);
      if (mounted) setState(() { _connected = false; _model = null; });
    } catch (error) { if (mounted) setState(() => _error = error.toString()); }
    finally { if (mounted) setState(() => _connecting = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = SupabaseService.client?.auth.currentUser;
    if (user == null) {
      return Scaffold(appBar: AppBar(title: Text(_t('AI','الذكاء الاصطناعي'))), body: ListView(padding: const EdgeInsets.all(24), children: [
        Card(elevation:0, child: Padding(padding: const EdgeInsets.all(20), child: Column(children:[
          const CircleAvatar(radius:30, child: Icon(Icons.account_circle_outlined,size:34)), const SizedBox(height:14),
          Text(_t('Sign in to NUS','سجّل دخولك في NUS'),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)), const SizedBox(height:8),
          Text(_t('Your personal AI connections and AI history belong to your NUS account.','اتصالات الذكاء الاصطناعي وسجل التحليلات بتوعك بيتحفظوا تحت حسابك في NUS.'),textAlign:TextAlign.center), const SizedBox(height:18),
          FilledButton.icon(onPressed:_signingIn?null:_signInWithGoogle,icon:_signingIn?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login_rounded),label:Text(_signingIn?_t('Opening Google…','جاري فتح Google…'):_t('Continue with Google','الدخول بحساب Google'))),
        ]))), if(_error!=null) Card(color:Theme.of(context).colorScheme.errorContainer,elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Text(_error!)))
      ]));
    }
    return Scaffold(appBar:AppBar(title:Text(_t('AI','الذكاء الاصطناعي'))),body:ListView(padding:const EdgeInsets.all(18),children:[
      Card(elevation:0,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const CircleAvatar(child:Icon(Icons.auto_awesome_rounded)),const SizedBox(width:12),Expanded(child:Text(_t('Your AI connections','اتصالات الذكاء الاصطناعي الخاصة بك'),style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900)))]),const SizedBox(height:10),
        Text(_t('NUS uses the AI provider you authorize. Your AI password is never entered into NUS.','NUS بيستخدم مزود الذكاء الاصطناعي اللي إنت بتوافق عليه، وكلمة مرور AI مش بتدخلها في NUS.')),const SizedBox(height:6),Text(user.email??'',style:const TextStyle(fontWeight:FontWeight.w700))
      ]))),const SizedBox(height:14),
      SegmentedButton<String>(segments:[ButtonSegment(value:'gemini',label:Text('Google Gemini'),icon:const Icon(Icons.cloud_outlined)),ButtonSegment(value:'openai',label:Text('OpenAI'),icon:const Icon(Icons.psychology_outlined))],selected:{_provider},onSelectionChanged:(v)=>_selectProvider(v.first)),const SizedBox(height:14),
      Card(elevation:0,child:ListTile(leading:Icon(_connected?Icons.link_rounded:Icons.link_off_rounded),title:Text(_connected?_t('Connected','متصل'):_t('Not connected','غير متصل')),subtitle:Text(_model??_t('No AI model connected yet.','لسه مفيش موديل AI متصل.')),trailing:_connected&&_provider=='gemini'?OutlinedButton(onPressed:_connecting?null:_disconnect,child:Text(_t('Disconnect','فصل'))):FilledButton(onPressed:_connecting||_provider!='gemini'?null:_connectGemini,child:Text(_connecting?_t('Connecting…','جاري الربط…'):_t('Connect','ربط'))))),
      if(_provider=='openai') Card(elevation:0,color:Theme.of(context).colorScheme.surfaceContainerHighest,child:Padding(padding:const EdgeInsets.all(16),child:Text(_t('OpenAI / ChatGPT is shown separately because signing in with ChatGPT does not give NUS access to ChatGPT conversations, billing, or an API account. NUS will not ask for your ChatGPT password. OpenAI connection will be enabled only through an explicitly supported user authorization flow.','OpenAI / ChatGPT ظاهر بشكل منفصل لأن تسجيل الدخول بـChatGPT ما بيديش NUS صلاحية لمحادثات ChatGPT أو الفوترة أو حساب الـAPI. NUS مش هيطلب باسورد ChatGPT. ربط OpenAI هيتفعل فقط من خلال طريقة تفويض للمستخدم تكون مدعومة رسميًا.'))),
      if(_error!=null) Card(color:Theme.of(context).colorScheme.errorContainer,elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Text(_error!,style:const TextStyle(fontWeight:FontWeight.w700))))
    ]));
  }
}

class _AiSettingsException implements Exception { const _AiSettingsException(this.message); final String message; @override String toString()=>message; }
