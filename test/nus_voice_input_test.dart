import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/today/domain/nus_voice_input.dart';

void main() {
  test('voice capability reports Arabic Egypt locale and transcript', () async {
    final fake = FakeNusVoiceInput(
      transcript: 'بكرة الساعة عشرة فكّرني أكلم الدكتور',
    );
    final state = NusVoiceInputState(input: fake);

    await state.checkAvailability();
    expect(state.available, isTrue);

    final transcript = await state.listen();
    expect(transcript, 'بكرة الساعة عشرة فكّرني أكلم الدكتور');
    expect(fake.lastLocaleId, 'ar-EG');
    expect(state.listening, isFalse);
  });

  test('unavailable capability stays safe and does not throw', () async {
    final state = NusVoiceInputState(
      input: FakeNusVoiceInput(available: false),
    );

    await state.checkAvailability();
    expect(state.available, isFalse);
    expect(await state.listen(), isNull);
    expect(state.error, isNull);
  });
}
