import 'package:shared_preferences/shared_preferences.dart';

class NusProactiveRecommendationSettings {
  const NusProactiveRecommendationSettings({SharedPreferences? preferences})
      : _preferences = preferences;

  static const enabledKey = 'nus.proactive_recommendations.enabled.v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<bool> isEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(enabledKey, enabled);
  }
}
