import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../domain/nus_voice_input.dart';

class SpeechToTextNusVoiceInput implements NusVoiceInput {
  SpeechToTextNusVoiceInput({stt.SpeechToText? engine}) : _engine = engine ?? stt.SpeechToText();

  final stt.SpeechToText _engine;
  bool _initialized = false;

  @override
  Future<bool> isAvailable() async {
    if (_initialized) return _engine.isAvailable;
    _initialized = await _engine.initialize(onError: (_) {}, onStatus: (_) {});
    return _initialized && _engine.isAvailable;
  }

  @override
  Future<String?> listen({String localeId = 'ar-EG'}) async {
    if (!await isAvailable()) return null;
    String? recognized;
    await _engine.listen(
      localeId: localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) => recognized = result.recognizedWords,
    );
    await _engine.stop();
    return recognized;
  }
}
