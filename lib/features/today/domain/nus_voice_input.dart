abstract interface class NusVoiceInput {
  Future<bool> isAvailable();

  Future<String?> listen({String localeId = 'ar-EG'});
}
