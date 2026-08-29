// lib/data/encoding_fix.dart
//
// Repair for double-encoded text in the garden's CSV exports.
//
// Kept free of Flutter imports so its self-check runs under plain
// `dart run --enable-asserts lib/data/encoding_fix.dart`. This is worth testing
// properly: section names and plant notes parsed from these files can reach the
// gardener's confirmation card and be written into the garden's records, and
// the append-only rules mean a corrupted Finnish string cannot be deleted
// afterwards — only annulled.

import 'dart:convert' show utf8;

/// CP1252 codepoints for bytes 0x80–0x9F. Latin-1 leaves that range as control
/// characters, so a plain `latin1.encode` cannot undo the damage.
const Map<int, int> _cp1252Reverse = {
  0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84, 0x2026: 0x85,
  0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88, 0x2030: 0x89, 0x0160: 0x8A,
  0x2039: 0x8B, 0x0152: 0x8C, 0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92,
  0x201C: 0x93, 0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
  0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B, 0x0153: 0x9C,
  0x017E: 0x9E, 0x0178: 0x9F,
};

/// Repairs UTF-8 bytes that were read as CP1252 and re-saved as UTF-8 — the
/// reason "Ä" appears as "Ã„" throughout these exports.
///
/// Conservative: only rewrites when the reversal yields valid UTF-8, so a
/// string that merely contains "Ã" legitimately is left alone.
String fixMojibake(String s) {
  if (!s.contains('Ã') && !s.contains('Â')) return s;

  final bytes = <int>[];
  for (final rune in s.runes) {
    if (rune < 0x100) {
      bytes.add(rune);
    } else if (_cp1252Reverse.containsKey(rune)) {
      bytes.add(_cp1252Reverse[rune]!);
    } else {
      return s; // not representable as CP1252 — not this kind of damage
    }
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return s; // reversal produced invalid UTF-8; keep the original
  }
}

// ─── Self-check ─────────────────────────────────────────────────────────────
void main() {
  // The real damage seen in the exports.
  assert(fixMojibake('TALVISAT. L. VÃ„LIMEREN ILMASTOALUE') ==
      'TALVISAT. L. VÄLIMEREN ILMASTOALUE');
  assert(fixMojibake('KESÃ„SATEIDEN ALUE') == 'KESÄSATEIDEN ALUE');
  assert(fixMojibake('HYÃ–TYKASVI OSASTO') == 'HYÖTYKASVI OSASTO');
  assert(fixMojibake('LÃ„Ã„KEKASVI OSASTO') == 'LÄÄKEKASVI OSASTO');
  assert(fixMojibake('VILLIYTYNEITÃ„ PUUTARHAKASVEJA') ==
      'VILLIYTYNEITÄ PUUTARHAKASVEJA');

  // Already-correct Finnish must survive untouched.
  assert(fixMojibake('KESÄSATEIDEN ALUE') == 'KESÄSATEIDEN ALUE');
  assert(fixMojibake('Rukoushelmi') == 'Rukoushelmi');
  assert(fixMojibake('') == '');

  // Plain ASCII is a no-op.
  assert(fixMojibake('TROOPPINEN HUONE') == 'TROOPPINEN HUONE');
  assert(fixMojibake('G-HA') == 'G-HA');

  // A legitimate "Ã" that is NOT mojibake must not be mangled. "Ã" alone
  // reverses to byte 0xC3, an incomplete UTF-8 sequence, so we keep the input.
  assert(fixMojibake('Ã') == 'Ã');

  // Idempotent — running it twice must not damage repaired text.
  final once = fixMojibake('KESÃ„SATEIDEN ALUE');
  assert(fixMojibake(once) == once);

  // ignore: avoid_print
  print('encoding_fix self-check ok');
}
