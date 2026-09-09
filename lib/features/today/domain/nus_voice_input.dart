import 'package:flutter/foundation.dart';

/// Platform-independent speech capability used by NUS voice-first capture.
///
/// This intentionally does not depend on a native speech package. A platform
/// adapter can be added later without coupling Today/Quick Add to a provider.
abstract interface class NusVoiceInput {
  Future<bool> isAvailable();

  Future<String?> listen({
    String localeId = 'ar-EG',
  });
}

class NusVoiceInputState extends ChangeNotifier {
  NusVoiceInputState({NusVoiceInput? input}) : _input = input;

  final NusVoiceInput? _input;
  bool _available = false;
  bool _checking = false;
  bool _listening = false;
  String? _error;
  String? _transcript;

  bool get available => _available;
  bool get checking => _checking;
  bool get listening => _listening;
  String? get error => _error;
  String? get transcript => _transcript;

  Future<void> checkAvailability() async {
    if (_input == null || _checking) return;
    _checking = true;
    _error = null;
    notifyListeners();
    try {
      _available = await _input!.isAvailable();
    } catch (error) {
      _available = false;
      _error = error.toString();
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<String?> listen({String localeId = 'ar-EG'}) async {
    if (_input == null || !_available || _listening) return null;
    _listening = true;
    _error = null;
    notifyListeners();
    try {
      final value = await _input!.listen(localeId: localeId);
      _transcript = value?.trim();
      return _transcript;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _listening = false;
      notifyListeners();
    }
  }

  void clearTranscript() {
    _transcript = null;
    notifyListeners();
  }
}

@visibleForTesting
class FakeNusVoiceInput implements NusVoiceInput {
  FakeNusVoiceInput({this.available = true, this.transcript});

  final bool available;
  final String? transcript;
  String? lastLocaleId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> listen({String localeId = 'ar-EG'}) async {
    lastLocaleId = localeId;
    return transcript;
  }
}
