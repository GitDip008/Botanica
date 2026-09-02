// lib/data/hunt_answers.dart
//
// Judging typed Plant Hunt answers.
//
// Visitors read the name off the garden's own metal tag, so the answer arrives
// in whatever form that tag uses — Finnish name, scientific name, or the
// everyday name they already knew. All three are accepted, and so is a near
// miss: "monstra deliciosa" from someone copying a tag at arm's length is a
// found plant, not a wrong answer.
//
// Deterministic on purpose. The old version asked an LLM whether an answer was
// right, which cost a network round trip per guess, could not be tested, and
// occasionally disagreed with itself on the same input. A name match is a
// string comparison; it does not need a language model.
//
// No Flutter imports — run the checks with:
//   dart run --enable-asserts lib/data/hunt_answers.dart

/// Folds an answer down to something comparable: lower case, no accents, no
/// punctuation, single spaces. "Jättipeikonlehti!" and "jattipeikonlehti"
/// have to land on the same string, because a phone keyboard set to English
/// makes the first one hard to type.
String normalizeAnswer(String s) {
  const accents = {
    'ä': 'a', 'å': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
    'ö': 'o', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss',
  };
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final mapped = accents[ch] ?? ch;
    // Keep letters, digits and spaces; everything else becomes a space so
    // "cut-leaf" and "cut leaf" agree.
    for (final c in mapped.split('')) {
      final code = c.codeUnitAt(0);
      final isLetter = code >= 97 && code <= 122;
      final isDigit = code >= 48 && code <= 57;
      buf.write(isLetter || isDigit ? c : ' ');
    }
  }
  return buf.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Levenshtein edit distance, two-row variant so it costs O(min) memory.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      cur[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final swap = prev;
    prev = cur;
    cur = swap;
  }
  return prev[b.length];
}

/// How close two names are, 0-100.
int _similarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final longest = a.length > b.length ? a.length : b.length;
  return (100 * (longest - editDistance(a, b)) / longest).round();
}

/// The result of judging one typed answer.
class AnswerScore {
  const AnswerScore(this.points, this.matched);

  /// 0-100. Also the points banked for the quest, so a confident answer is
  /// worth more than a half-remembered one and the leaderboard can separate
  /// them.
  final int points;

  /// Which accepted name it came closest to. Never shown to a visitor who has
  /// not solved the quest — it would give the plant away.
  final String matched;

  /// Good enough to count as found. Set where a genuine typo still passes but
  /// a different plant does not: "sinapis alba" against "sinapsis alba" is 92,
  /// while "monstera deliciosa" against "sinapis alba" is 28.
  bool get isCorrect => points >= 68;

  /// Right plant, roughly spelled — worth saying so, since the visitor is
  /// standing at the correct tag and should not be sent away.
  bool get isApproximate => isCorrect && points < 90;
}

/// Judges [typed] against every name this plant answers to.
///
/// Containment is checked as well as distance, because "the monstera plant"
/// and "grape" are both right but neither is close to the full tag text by
/// edit distance alone.
AnswerScore scoreAnswer(String typed, List<String> accepted) {
  final t = normalizeAnswer(typed);
  if (t.isEmpty) return const AnswerScore(0, '');

  var best = 0;
  var bestName = '';
  for (final name in accepted) {
    final a = normalizeAnswer(name);
    if (a.isEmpty) continue;

    var score = _similarity(t, a);

    // A short exact name inside a longer answer, or vice versa. Capped below
    // 100 so an exact match still ranks above a wordy one.
    if (score < 96 && (t.contains(a) || a.contains(t))) {
      final shorter = t.length < a.length ? t.length : a.length;
      // Guard against one or two letters matching inside a long name:
      // "a" is contained in "sinapis alba" but means nothing.
      if (shorter >= 4) {
        final containment = 88 + (12 * shorter ~/ (t.length > a.length ? t.length : a.length));
        if (containment > score) score = containment > 96 ? 96 : containment;
      }
    }

    if (score > best) {
      best = score;
      bestName = name;
    }
  }
  return AnswerScore(best, bestName);
}

/// Every name each hunt plant answers to, keyed by a stable id.
///
/// Three families of name, because three different visitors will read three
/// different things: the Finnish name at the top of the garden's tag, the Latin
/// binomial under it, and whatever they already called the plant at home.
/// Matching is fuzzy, so misspellings do not belong here — only real
/// alternative names.
const kHuntAccepted = <String, List<String>>{
  'cacao': [
    'kaakaopuu', 'kaakao', 'Theobroma cacao', 'Theobroma',
    'cacao', 'cocoa', 'cacao tree', 'cocoa tree', 'chocolate tree', 'kakao',
  ],
  'monstera': [
    'jättipeikonlehti', 'peikonlehti', 'Monstera deliciosa', 'monstera',
    'swiss cheese plant', 'cheese plant', 'split leaf philodendron',
    'fruit salad plant', 'ceriman',
  ],
  'kultapallo': [
    'kultapallo', 'Rudbeckia laciniata', 'rudbeckia', 'goldquelle',
    'golden glow', 'cutleaf coneflower', 'cut leaf coneflower',
    'coneflower', 'tall coneflower', 'green headed coneflower',
  ],
  'grape': [
    'tarhaviiniköynnös', 'viiniköynnös', 'viinirypäle', 'rypäle',
    'Vitis vinifera', 'Vitis vinifera subsp. vinifera', 'vitis',
    'grape', 'grapes', 'grapevine', 'grape vine', 'wine grape',
    'common grape vine',
  ],
  'mustard': [
    'keltasinappi', 'sinappi', 'Sinapis alba', 'sinapis',
    'white mustard', 'yellow mustard', 'mustard',
  ],
};

// ── Self-check ───────────────────────────────────────────────────────────────

void main() {
  // Normalisation
  assert(normalizeAnswer('  Jättipeikonlehti! ') == 'jattipeikonlehti');
  assert(normalizeAnswer('Cut-leaf  Coneflower') == 'cut leaf coneflower');
  assert(normalizeAnswer('Tarhaviiniköynnös') == 'tarhaviinikoynnos');

  const cacao = ['kaakaopuu', 'Theobroma cacao', 'cacao', 'cocoa', 'chocolate tree'];

  // Exact, in any of the three name systems the tag offers.
  assert(scoreAnswer('kaakaopuu', cacao).points == 100);
  assert(scoreAnswer('Theobroma cacao', cacao).points == 100);
  assert(scoreAnswer('COCOA', cacao).points == 100);

  // Typos still find the plant.
  assert(scoreAnswer('theobroma cacoa', cacao).isCorrect);
  assert(scoreAnswer('kaakaopu', cacao).isCorrect);

  // ...but score below a clean answer, which is the whole point of points.
  // One dropped letter still reads as confident; a mangled binomial does not.
  assert(scoreAnswer('kaakaopu', cacao).points < 100);
  assert(scoreAnswer('theobroma cacoa', cacao).isApproximate);

  // A wordier answer containing the name counts.
  assert(scoreAnswer('the cocoa tree', cacao).isCorrect);

  // A different plant does not.
  assert(!scoreAnswer('Sinapis alba', cacao).isCorrect);
  assert(!scoreAnswer('grape', cacao).isCorrect);
  assert(!scoreAnswer('', cacao).isCorrect);

  // A stray letter must not match by containment.
  assert(!scoreAnswer('a', cacao).isCorrect);

  print('hunt_answers: all assertions passed');
}
