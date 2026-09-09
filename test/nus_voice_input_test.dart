import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/today/domain/nus_voice_input.dart';

class FakeVoice implements NusVoiceInput {
  FakeVoice({required this.available, this.transcript});

  final bool available;
  final String? transcript;
  String? localeId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> listen({String localeId = 'ar-EG'}) async {
    this.localeId = localeId;
    return transcript;
  }
}

void main() {
  test('voice contract defaults to Egyptian Arabic', () async {
    final fake = FakeVoice(
      available: true,
      transcript: 'بكرة الساعة عشرة فكّرني أكلم الدكتور',
    );

    expect(await fake.isAvailable(), isTrue);
    expect(await fake.listen(), 'بكرة الساعة عشرة فكّرني أكلم الدكتور');
    expect(fake.localeId, 'ar-EG');
  });

  test('unavailable voice remains a safe optional capability', () async {
    final fake = FakeVoice(available: false);
    expect(await fake.isAvailable(), isFalse);
  });
}
