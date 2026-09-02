// lib/screens/plant_hunt_screen.dart
//
// A five-stop scavenger hunt through the garden.
//
// The single rule this screen exists to protect: nothing on the quest card may
// name the plant before it is found. That rules out the Finnish name, the
// English family name ("Cacao family" is the answer), and even the emoji — a
// chocolate bar or a bunch of grapes gives it away as surely as the word does.
// The header therefore carries a number and nothing else, and the reference
// photo sits behind the location hint rather than beside the clue.
//
// Answers are typed, read off the garden's own metal tags, and judged locally
// by lib/data/hunt_answers.dart against every name a tag might show — Finnish,
// scientific, or everyday. Near misses still count and score fewer points, so
// the leaderboard separates a confident answer from a half-remembered one.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/hunt_answers.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/hunt_score_service.dart';
import '../services/language_service.dart';
import '../services/usage_tracking_service.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Challenge {
  const _Challenge({
    required this.questNumber,
    required this.clues,
    required this.whereToLook,
    required this.image,
    required this.targetName,
    required this.targetScientific,
    required this.accepted,
  });

  final String questNumber;

  /// Shown verbatim, one numbered line each — the garden wrote these.
  final List<String> clues;

  /// Revealed only when the visitor asks for it.
  final String whereToLook;

  /// Reference photo of this specimen, taken in this garden. Behind the hint
  /// for the same reason: seeing the plant is most of the answer.
  final String image;

  /// Shown only after the quest is solved, or when a stuck visitor asks.
  final String targetName;
  final String targetScientific;

  /// Every name this plant answers to: what is on the tag, and what a visitor
  /// would call it at home. Matching is fuzzy, so only distinct forms are
  /// needed here — not every possible misspelling.
  final List<String> accepted;
}

// final, not const: the accepted-name lists come from a map lookup, which is
// not a constant expression. The quests are still immutable.
final _kChallenges = <_Challenge>[
  _Challenge(
    questNumber: '1',
    clues: [
      'This plant’s fruit matures over a period comparable to a human pregnancy.',
      'This plant is cauliflorous, i.e. it produces its flowers and often its '
          'fruits directly from the trunk or older woody stems, rather than '
          'from the tips of branches.',
      'For centuries, the seeds of this plant have been used to prepare a '
          'comforting hot drink.',
    ],
    whereToLook: 'You can find me in greenhouse Romeo.',
    image: 'assets/plant_hunt/cacao_plant.jpg',
    targetName: 'Cacao tree',
    targetScientific: 'Theobroma cacao',
    accepted: kHuntAccepted['cacao']!,
  ),
  _Challenge(
    questNumber: '2',
    clues: [
      'My species name, deliciosa, means “delicious”. What might that tell you '
          'about my fruit?',
      'You can grow me at home, but my fruit takes almost nine months to ripen '
          'and is unsafe to eat before it is fully ripe.',
      'My large leaves develop natural holes and splits, making me one of the '
          'world\'s most recognisable houseplants.',
    ],
    whereToLook: 'You can find me in greenhouse Romeo.',
    image: 'assets/plant_hunt/monstera.jpg',
    targetName: 'Swiss cheese plant',
    targetScientific: 'Monstera deliciosa',
    accepted: kHuntAccepted['monstera']!,
  ),
  _Challenge(
    questNumber: '3',
    clues: [
      'I bloom like a golden pom-pom high above the garden. You can easily grow '
          'me at home, and I come back year after year.',
      'Gardeners have grown me for centuries for my long-lasting golden '
          'flowers. Find the plant that looks like a little sun on a tall stem.',
    ],
    whereToLook: 'This is a decorative plant in the outdoor garden.',
    image: 'assets/plant_hunt/kultapallo.jpg',
    targetName: 'Cutleaf coneflower',
    targetScientific: "Rudbeckia laciniata 'Goldquelle'",
    accepted: kHuntAccepted['kultapallo']!,
  ),
  _Challenge(
    questNumber: '4',
    clues: [
      'For thousands of years, people have cultivated me for the sweet clusters '
          'hanging from my branches.',
      'My twisting tendrils help me climb towards the sunlight.',
      'From ancient empires to modern gardens, I have travelled with people '
          'across continents.',
    ],
    whereToLook: 'You can find me in greenhouse Julia.',
    image: 'assets/plant_hunt/grape.jpg',
    targetName: 'Grapevine',
    targetScientific: 'Vitis vinifera subsp. vinifera',
    accepted: kHuntAccepted['grape']!,
  ),
  _Challenge(
    questNumber: '5',
    clues: [
      'My bright yellow flowers hide tiny seeds with a surprisingly strong '
          'flavour.',
      'Many Finns enjoy a product made from my seeds alongside grilled sausage.',
      'For centuries, my seeds have been valued as both a spice and a '
          'condiment.',
    ],
    whereToLook: 'You can find me in the economical and medicinal plants '
        'section (FI hyöty- ja lääkekasvit).',
    image: 'assets/plant_hunt/mustard.jpg',
    targetName: 'White mustard',
    targetScientific: 'Sinapis alba',
    accepted: kHuntAccepted['mustard']!,
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlantHuntScreen extends StatefulWidget {
  const PlantHuntScreen({super.key});

  @override
  State<PlantHuntScreen> createState() => _PlantHuntScreenState();
}

enum _StopState { pending, correct, wrong }

class _PlantHuntScreenState extends State<PlantHuntScreen> {
  int _current = 0;
  final List<_StopState> _states =
      List.filled(_kChallenges.length, _StopState.pending);

  /// Points banked per quest, 0 until solved.
  final List<int> _points = List.filled(_kChallenges.length, 0);

  String? _feedback;
  bool _feedbackGood = false;
  bool _allDone = false;

  // After three wrong answers, offer the name rather than let someone give up.
  final List<int> _wrongCounts = List.filled(_kChallenges.length, 0);
  final List<bool> _answerRevealed =
      List.filled(_kChallenges.length, false);

  final _textCtrl = TextEditingController();
  bool _showHint = false;

  int get _total => _points.fold(0, (a, b) => a + b);
  int get _solved => _states.where((s) => s == _StopState.correct).length;

  @override
  void initState() {
    super.initState();
    UsageTrackingService.instance.log(UsageTrackingService.featurePlantHunt);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Judging ────────────────────────────────────────────────────────────────

  void _submit() {
    final typed = _textCtrl.text.trim();
    if (typed.isEmpty) return;

    final challenge = _kChallenges[_current];
    final score = scoreAnswer(typed, challenge.accepted);

    setState(() {
      if (score.isCorrect) {
        _states[_current] = _StopState.correct;
        // A revealed answer still counts as found, but banks nothing — the
        // points are for working it out.
        _points[_current] = _answerRevealed[_current] ? 0 : score.points;
        _feedbackGood = true;
        _feedback = _answerRevealed[_current]
            ? 'Found it. No points for this one — you had the answer.'
            : score.isApproximate
                ? 'Found it! Spelling was close enough. +${score.points} points'
                : 'Found it! +${score.points} points';
      } else {
        _states[_current] = _StopState.wrong;
        _wrongCounts[_current]++;
        _feedbackGood = false;
        // Deliberately says nothing about what the plant is, not even how
        // close the guess was — "warmer" would narrow it down.
        _feedback = 'Not this one. Read the tag on the plant and try again.';
      }
    });
  }

  void _nextChallenge() {
    if (_current < _kChallenges.length - 1) {
      setState(() {
        _current++;
        _textCtrl.clear();
        _showHint = false;
        _feedback = null;
      });
    } else {
      BadgeService.instance.award('plant_hunt_completed');
      final user = AuthService.instance.currentUser;
      if (user != null) {
        HuntScoreService.instance.submit(
          uid: user.id,
          displayName: user.displayName,
          total: _total,
          solved: _solved,
        );
      }
      setState(() => _allDone = true);
    }
  }

  void _retryChallenge() {
    setState(() {
      _states[_current] = _StopState.pending;
      _textCtrl.clear();
      _feedback = null;
    });
  }

  /// Lets someone stuck on one plant carry on with the rest of the hunt.
  void _skipChallenge() {
    setState(() {
      _states[_current] = _StopState.wrong;
      _points[_current] = 0;
      _feedback = null;
    });
    _nextChallenge();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🔍 Plant Hunt',
            style: TextStyle(
                color: Color(0xFFE8F5E9), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Leaderboard',
            icon: const Icon(Icons.leaderboard_rounded,
                color: Color(0xFF66BB6A)),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HuntLeaderboardScreen())),
          ),
        ],
      ),
      body: _allDone ? _buildBadge() : _buildHunt(),
    );
  }

  Widget _buildHunt() {
    final challenge = _kChallenges[_current];
    final state = _states[_current];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _progressDots(),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2E7D32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: a number and a running total. Nothing here may hint
                // at which plant this is.
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(challenge.questNumber,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Quest ${challenge.questNumber} of ${_kChallenges.length}',
                        style: const TextStyle(
                            color: Color(0xFFE8F5E9),
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text('$_total pts',
                        style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),

                Row(children: [
                  const Icon(Icons.format_quote,
                      color: Color(0xFF2E7D32), size: 16),
                  const SizedBox(width: 4),
                  Text(LanguageService.instance.strings.yourClue,
                      style: const TextStyle(
                          color: Color(0xFF66BB6A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ]),
                const SizedBox(height: 8),

                // The garden's own wording, one numbered line each.
                for (var i = 0; i < challenge.clues.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text('${i + 1}.',
                              style: const TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Text(challenge.clues[i],
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 13,
                                  height: 1.55)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _showHint = !_showHint),
                  child: Row(children: [
                    Icon(
                      _showHint ? Icons.expand_less : Icons.explore_outlined,
                      color: const Color(0xFF4CAF50),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(_showHint ? 'Hide location hint' : 'Show where to look',
                        style: const TextStyle(
                            color: Color(0xFF4CAF50), fontSize: 12)),
                  ]),
                ),
                if (_showHint) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1F14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📍 ${challenge.whereToLook}',
                            style: const TextStyle(
                                color: Color(0xFF66BB6A),
                                fontSize: 12,
                                height: 1.5)),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            challenge.image,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 18),

          // ── Answer ──────────────────────────────────────────────────────
          const Text('WHAT IS IT CALLED?',
              style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Text(
            'Read the name off the plant’s tag. Finnish, Latin or the everyday '
            'name all count, and close spelling is fine.',
            style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            enabled: state != _StopState.correct,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              hintText: 'Type the name from the tag…',
              prefixIcon: Icon(Icons.local_offer_outlined,
                  color: Color(0xFF4CAF50)),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),

          if (_feedback != null)
            AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _feedbackGood
                    ? Colors.green[900]!.withOpacity(0.4)
                    : Colors.red[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _feedbackGood
                      ? Colors.greenAccent
                      : Colors.red[400]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _feedbackGood ? Icons.check_circle : Icons.close,
                    color: _feedbackGood
                        ? Colors.greenAccent
                        : Colors.red[400]!,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_feedback!,
                        style: TextStyle(
                            color: _feedbackGood
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontSize: 14,
                            height: 1.4)),
                  ),
                ],
              ),
            ),

          _buildActionButton(state, challenge),
        ],
      ),
    );
  }

  Widget _progressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kChallenges.length, (i) {
        final s = _states[i];
        final isActive = i == _current;
        final done = s == _StopState.correct;
        final color = done
            ? Colors.greenAccent
            : isActive
                ? const Color(0xFF66BB6A)
                : const Color(0xFF2E7D32).withOpacity(0.3);
        return AnimatedContainer(
          duration: 300.ms,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isActive ? 34 : 26,
          height: isActive ? 34 : 26,
          decoration: BoxDecoration(
            color: color.withOpacity(isActive ? 0.3 : 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: isActive ? 2 : 1),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, color: color, size: 13)
                : Text('${i + 1}',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton(_StopState state, _Challenge challenge) {
    if (state == _StopState.correct) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          _current < _kChallenges.length - 1
              ? LanguageService.instance.strings.nextQuest
              : LanguageService.instance.strings.claimYourBadge,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: _nextChallenge,
      );
    }

    if (state == _StopState.wrong) {
      final showReveal = _wrongCounts[_current] >= 3;
      return Column(
        children: [
          if (showReveal) ...[
            if (_answerRevealed[_current])
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.lightbulb_rounded,
                          color: Color(0xFFFFD54F), size: 16),
                      const SizedBox(width: 6),
                      Text(LanguageService.instance.strings.theAnswerIs,
                          style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      '${challenge.targetName} (${challenge.targetScientific})',
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(LanguageService.instance.strings.goFindItToContinue,
                        style: const TextStyle(
                            color: Color(0xFF81C784), fontSize: 12)),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD54F),
                    side: const BorderSide(color: Color(0xFFFFD54F)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                  label: Text(
                      LanguageService.instance.strings.tapToKnowTheAnswer),
                  onPressed: () =>
                      setState(() => _answerRevealed[_current] = true),
                ),
              ),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: BorderSide(color: Colors.orange[400]!),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 0),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(LanguageService.instance.strings.tryAgain),
            onPressed: _retryChallenge,
          ),
          if (showReveal)
            TextButton(
              onPressed: _skipChallenge,
              child: const Text('Skip this plant',
                  style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12)),
            ),
        ],
      );
    }

    final canSubmit = _textCtrl.text.trim().isNotEmpty;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            canSubmit ? const Color(0xFF2E7D32) : const Color(0xFF1A2E1E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.send_rounded),
      label: Text(LanguageService.instance.strings.submitAnswer,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      onPressed: canSubmit ? _submit : null,
    );
  }

  // ── Badge ──────────────────────────────────────────────────────────────────

  Widget _buildBadge() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF1A2E1E),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.greenAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 64))
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 12),
                  const Text(
                    'PLANT DETECTIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text('$_total',
                      style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 40,
                          fontWeight: FontWeight.w900)),
                  Text('points · $_solved of ${_kChallenges.length} found',
                      style: const TextStyle(
                          color: Color(0xFF9CCC9F), fontSize: 12.5)),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF2E7D32)),
                  const SizedBox(height: 12),
                  // Names are safe here: the hunt is over.
                  for (var i = 0; i < _kChallenges.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            _states[i] == _StopState.correct
                                ? Icons.check_circle
                                : Icons.remove_circle_outline,
                            size: 15,
                            color: _states[i] == _StopState.correct
                                ? Colors.greenAccent
                                : const Color(0xFF4A7A50),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_kChallenges[i].targetName,
                                style: const TextStyle(
                                    color: Color(0xFFE8F5E9), fontSize: 13)),
                          ),
                          Text('${_points[i]}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),

            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.greenAccent, size: 30),
                  SizedBox(height: 10),
                  Text(
                    'Show this badge to a garden staff member\nat the info desk for a small surprise! 🎁',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFFE8F5E9), fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: const Color(0xFF231A00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.leaderboard_rounded),
              label: const Text('See the leaderboard',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HuntLeaderboardScreen())),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.home, color: Color(0xFF66BB6A), size: 18),
              label: Text(LanguageService.instance.strings.backToHome,
                  style: const TextStyle(color: Color(0xFF66BB6A))),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

class HuntLeaderboardScreen extends StatelessWidget {
  const HuntLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUser?.id;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        title: const Text('Plant Hunt leaderboard',
            style: TextStyle(color: Color(0xFFE8F5E9))),
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
      ),
      body: StreamBuilder<List<HuntScore>>(
        stream: HuntScoreService.instance.watchTop(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nobody has finished the hunt yet.\nBe the first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              final mine = r.uid == myUid;
              final medal = i == 0
                  ? const Color(0xFFFFD54F)
                  : i == 1
                      ? const Color(0xFFCFD8DC)
                      : i == 2
                          ? const Color(0xFFBCAAA4)
                          : const Color(0xFF2A4A2F);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mine
                      ? const Color(0xFF16301D)
                      : const Color(0xFF111F16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: mine
                        ? const Color(0xFF66BB6A)
                        : (i < 3 ? medal : const Color(0xFF2A4A2F)),
                    width: i < 3 || mine ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: medal,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mine ? '${r.displayName}  (you)' : r.displayName,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600)),
                          Text('${r.solved} of ${_kChallenges.length} found',
                              style: const TextStyle(
                                  color: Color(0xFF4A7A50), fontSize: 11.5)),
                        ],
                      ),
                    ),
                    Text('${r.total}',
                        style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('pts',
                          style: TextStyle(
                              color: Color(0xFF4A7A50), fontSize: 10.5)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
