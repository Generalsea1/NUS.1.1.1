import 'package:flutter/material.dart';

import '../application/user_ai_run_repository.dart';

class AiHistoryPage extends StatefulWidget {
  const AiHistoryPage({super.key, this.isArabic = true});
  final bool isArabic;

  @override
  State<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends State<AiHistoryPage> {
  final _repository = const UserAiRunRepository();
  List<Map<String, dynamic>> _runs = const [];
  bool _loading = true;

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await _repository.recent();
      if (mounted) setState(() => _runs = runs);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('AI history', 'سجل الذكاء الاصطناعي'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _runs.isEmpty
              ? Center(child: Text(_t('No AI runs yet.', 'لسه مفيش تحليلات AI اتسجلت.')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _runs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final run = _runs[index];
                      final response = run['response'];
                      final recommendation = response is Map ? response['recommendation'] as String? : null;
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                          title: Text('${run['provider']} • ${run['model'] ?? ''}'),
                          subtitle: Text(recommendation ?? _t('Household AI run', 'تحليل خطة البيت')),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
