// Every literal passed to tr() must have a Finnish and Swedish row, otherwise
// the UI silently falls back to English in that spot.

import 'dart:io';

import 'package:botanica_ar/i18n/ui_strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// A single complete literal as tr()'s first argument; concatenated literals and
// interpolated strings are skipped (the extractor never produces them).
final _call = RegExp(r"""\btr\(\s*(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")\s*[,)]""");

String _unescape(String s) => s.replaceAllMapped(
    RegExp(r'\\(.)'), (m) => m[1] == 'n' ? '\n' : m[1]!);

void main() {
  test('every tr() literal is translated to fi and sv', () {
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final code = f
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final m in _call.allMatches(code)) {
        final raw = m[1] ?? m[2]!;
        if (raw.contains(r'$')) continue; // interpolated
        final key = _unescape(raw);
        final row = kUiStrings[key];
        if (row == null || row[0].isEmpty || row[1].isEmpty) {
          missing.add('${f.path}: $key');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
