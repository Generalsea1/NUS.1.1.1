import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FinancialAdvisorDiagnosticEvent {
  const FinancialAdvisorDiagnosticEvent({
    required this.timestamp,
    required this.line,
  });

  final DateTime timestamp;
  final String line;
}

class FinancialAdvisorDiagnostics extends ChangeNotifier {
  FinancialAdvisorDiagnostics._();

  static final FinancialAdvisorDiagnostics instance = FinancialAdvisorDiagnostics._();

  static const int _maxEvents = 500;
  final List<FinancialAdvisorDiagnosticEvent> _events = <FinancialAdvisorDiagnosticEvent>[];

  List<FinancialAdvisorDiagnosticEvent> get events => List<FinancialAdvisorDiagnosticEvent>.unmodifiable(_events);

  void record(String line) {
    final safeLine = _sanitize(line);
    _events.add(
      FinancialAdvisorDiagnosticEvent(
        timestamp: DateTime.now(),
        line: safeLine,
      ),
    );
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    notifyListeners();
    print(safeLine);
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  String buildReport() {
    if (_events.isEmpty) return 'DEVELOPER DIAGNOSTICS\nNo diagnostic events captured.';
    final lines = <String>[
      'DEVELOPER DIAGNOSTICS',
      'NUS Financial Advisor runtime diagnostic report',
      '',
      ..._events.map((event) => '${_formatTimestamp(event.timestamp)}  ${event.line}'),
    ];
    return lines.join('\n');
  }

  Future<void> copyReport() async {
    await Clipboard.setData(ClipboardData(text: buildReport()));
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    final ms = local.millisecond.toString().padLeft(3, '0');
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hh:$mm:$ss.$ms';
  }

  String _sanitize(String value) {
    var result = value;
    result = result.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false), 'Bearer [REDACTED]');
    result = result.replaceAll(RegExp(r'AIza[0-9A-Za-z_-]{20,}'), '[REDACTED_API_KEY]');
    result = result.replaceAll(RegExp(r'(api[_-]?key\s*[=:]\s*)[^\s,]+', caseSensitive: false), r'\1[REDACTED]');
    result = result.replaceAll(RegExp(r'(access[_-]?token\s*[=:]\s*)[^\s,]+', caseSensitive: false), r'\1[REDACTED]');
    result = result.replaceAll(RegExp(r'(refresh[_-]?token\s*[=:]\s*)[^\s,]+', caseSensitive: false), r'\1[REDACTED]');
    result = result.replaceAll(RegExp(r'(cookie\s*[=:]\s*)[^\s,]+', caseSensitive: false), r'\1[REDACTED]');
    return result;
  }
}

class FinancialAdvisorDiagnosticsPage extends StatelessWidget {
  const FinancialAdvisorDiagnosticsPage({super.key});

  static const _title = 'DEVELOPER DIAGNOSTICS';

  @override
  Widget build(BuildContext context) {
    final diagnostics = FinancialAdvisorDiagnostics.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text(_title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: diagnostics.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: diagnostics,
          builder: (context, _) {
            final events = diagnostics.events;
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    _title,
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.7),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: events.isEmpty ? null : diagnostics.clear,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Clear Logs'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: diagnostics.copyReport,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copy Diagnostic Report'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: events.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No [FA_DIAG] events captured yet.'),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatEventTime(event.timestamp),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SelectableText(
                                        event.line,
                                        style: const TextStyle(fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatEventTime(DateTime value) {
    final local = value.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}.${local.millisecond.toString().padLeft(3, '0')}';
    return '$date\n$time';
  }
}
