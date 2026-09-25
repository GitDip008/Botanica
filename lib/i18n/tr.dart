// lib/i18n/tr.dart
//
// `tr('English text')` — translate a UI string into the current language.
//
// Why a second mechanism next to AppStrings: AppStrings has one hand-written
// getter per string, which is fine for the ~400 it holds, but most screens
// were written with English literals inline and converting several hundred of
// them into getters by hand is how translations get skipped. Here the English
// text is the key, so a screen reads exactly as before with `tr(...)` around
// it, and every translation lives in one generated table (ui_strings.g.dart).
//
// Variables use numbered placeholders, so a translator can move them:
//   tr('{0} plants · {1} sections', [n, s])
//
// A missing translation falls back to the English text rather than failing.
// test/i18n_coverage_test.dart is what stops that fallback from shipping.

import '../services/language_service.dart';
import 'app_strings.dart';
import 'ui_strings.g.dart';

String tr(String en, [List<Object?> args = const []]) {
  var out = en;
  final lang = LanguageService.activeOrDefault;
  if (lang != AppLanguage.en) {
    final row = kUiStrings[en];
    if (row != null) {
      final t = lang == AppLanguage.fi ? row[0] : row[1];
      if (t.isNotEmpty) out = t;
    }
  }
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i]}');
  }
  return out;
}

/// Locale code for DateFormat, matching the app language.
String trLocale() => switch (LanguageService.activeOrDefault) {
      AppLanguage.fi => 'fi',
      AppLanguage.sv => 'sv',
      AppLanguage.en => 'en',
    };

/// The app language's English name, for telling an LLM what to write in.
String trLanguageName() => switch (LanguageService.activeOrDefault) {
      AppLanguage.fi => 'Finnish',
      AppLanguage.sv => 'Swedish',
      AppLanguage.en => 'English',
    };
