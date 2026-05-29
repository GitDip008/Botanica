import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/app_strings.dart';

/// App-wide language state. Provided via Provider in main.dart, so any widget
/// can `context.watch<LanguageService>()` and rebuild on change.
class LanguageService extends ChangeNotifier {
  static const _prefsKey = 'app_language';

  AppLanguage _current = AppLanguage.en;
  AppLanguage get current => _current;
  AppStrings get strings => AppStrings(_current);

  LanguageService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _current = AppLanguage.fromCode(code);
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_current == lang) return;
    _current = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.code);
  }

  // Convenience singleton accessor for non-UI code (LLM prompts).
  static LanguageService? _instance;
  static LanguageService get instance => _instance ??= LanguageService();
  static void register(LanguageService svc) => _instance = svc;
}
