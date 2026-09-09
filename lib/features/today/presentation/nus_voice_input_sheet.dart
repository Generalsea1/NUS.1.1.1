import 'package:flutter/material.dart';

import '../domain/nus_voice_input.dart';

class NusVoiceInputSheet extends StatefulWidget {
  const NusVoiceInputSheet({super.key, required this.voice});

  final NusVoiceInput voice;

  @override
  State<NusVoiceInputSheet> createState() => _NusVoiceInputSheetState();
}

class _NusVoiceInputSheetState extends State<NusVoiceInputSheet> {
  late final NusVoiceInputState _state = NusVoiceInputState(input: widget.voice)
    ..addListener(_onChange);

  @override
  void initState() {
    super.initState();
    _state.checkAvailability();
  }

  void _onChange() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    _state.removeListener(_onChange);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcript = _state.transcript;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'إضافة بالصوت',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('اتكلم بجملة قصيرة، وبعدها راجع النص قبل الحفظ.'),
            const SizedBox(height: 20),
            if (_state.checking)
              const CircularProgressIndicator()
            else if (!_state.available)
              const Text('الإدخال الصوتي غير متاح على هذا الجهاز حاليًا.')
            else ...[
              FilledButton.icon(
                key: const Key('voice-listen'),
                onPressed: _state.listening ? null : _state.listen,
                icon: Icon(_state.listening ? Icons.mic : Icons.mic_none),
                label: Text(_state.listening ? 'جاري الاستماع...' : 'ابدأ الكلام'),
              ),
              if (transcript != null && transcript.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(transcript),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _state.clearTranscript,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ],
            if (_state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                'حصلت مشكلة في الإدخال الصوتي. جرّب مرة أخرى.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
