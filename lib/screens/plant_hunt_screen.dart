// lib/screens/plant_hunt_screen.dart
//
// A five-stop scavenger hunt through the garden.
//
// The rule this screen exists to protect: nothing on the quest card may name
// the plant before it is found. That rules out the Finnish name, the English
// family name ("Cacao family" is the answer), and even the emoji — a chocolate
// bar names a plant as surely as the word does. The header carries a number
// and a score, nothing else.
//
// Submitting takes BOTH a photograph and a typed name. The photo has to come
// from the camera inside this app: there is no gallery picker and no file
// input anywhere in the flow, so a picture pulled off the internet cannot be
// submitted. The typed name is read off the garden's own metal tag and judged
// locally by lib/data/hunt_answers.dart — Finnish, scientific or everyday, and
// near misses still count for slightly fewer points.
//
// Hints cost points, and the cost is always shown and confirmed before the
// hint appears. A hint a visitor did not knowingly buy would be a bug.

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/hunt_answers.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/camera_utils.dart';
import '../services/hunt_score_service.dart';
import '../services/hunt_submission_service.dart';
import '../services/language_service.dart';
import '../services/plant_identification_service.dart';
import '../services/usage_tracking_service.dart';
import '../services/wikipedia_image_service.dart';
import '../widgets/zoomable_camera_preview.dart';

// ─── Scoring ──────────────────────────────────────────────────────────────────

/// What each plant is worth before hints.
const kMaxQuestPoints = 100;

/// Cost of the first hint — where in the garden to look.
const kLocationHintCost = 15;

/// Cost of the second hint — a photograph of the plant itself. Dearer because
/// seeing the plant is most of the puzzle.
const kPhotoHintCost = 20;

/// Cost of submitting a photo the identifier would not confirm.
///
/// Priced low on purpose: a refusal is usually the identifier's failing rather
/// than the visitor's, and it is still gated behind a second rejected photo
/// and never offered for an empty frame. The trade is deliberate — it no
/// longer deters someone who knows the name from photographing any leaf in the
/// garden, but it stops an honest visitor being punished for a machine's
/// mistake, which is the likelier problem at a friendly event.
const kUncheckedPhotoCost = 10;

/// Points banked for a quest, after hints.
///
/// Buying both hints on the roughest accepted answer still leaves 23 points,
/// so finding the plant is always worth something without needing a floor to
/// say so. The clamp at zero is not decoration: firestore.rules rejects a
/// negative total, so a future change to the hint costs must not be able to
/// produce one.
int questPoints({
  required int answerScore,
  required bool usedLocationHint,
  required bool usedPhotoHint,
  required bool answerRevealed,
  bool uncheckedPhoto = false,
  int uncheckedPhotoCost = kUncheckedPhotoCost,
}) {
  // Being told the answer outright banks nothing; the points are for working
  // it out.
  if (answerRevealed) return 0;
  var p = answerScore;
  if (usedLocationHint) p -= kLocationHintCost;
  if (usedPhotoHint) p -= kPhotoHintCost;
  if (uncheckedPhoto) p -= uncheckedPhotoCost;
  // Every cost together can exceed the best answer, so this clamp is load
  // bearing: firestore.rules rejects a negative total outright.
  return p < 0 ? 0 : p;
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Challenge {
  const _Challenge({
    required this.questNumber,
    required this.clues,
    required this.whereToLook,
    required this.targetName,
    required this.targetScientific,
    required this.families,
    required this.accepted,
    this.freeUncheckedPhoto = false,
  });

  final String questNumber;

  /// Shown verbatim, one numbered line each — the garden wrote these.
  final List<String> clues;

  /// First hint. Costs [kLocationHintCost].
  final String whereToLook;

  /// Shown only after the quest is solved, or when a stuck visitor asks.
  final String targetName;

  /// Also what the Wikipedia photo hint is looked up by, and what the
  /// submitted photograph is checked against.
  final String targetScientific;

  /// Families the photo check will accept — see [kHuntFamilies].
  final List<String> families;

  /// Waives the unconfirmed-photo cost for this plant.
  ///
  /// Set where the identifier is known to struggle: kultapallo is a garden
  /// cultivar in a bed of lookalike yellow composites, and it is regularly
  /// read as a different plant or as nothing at all. Charging for the app's
  /// own blind spot would be charging the visitor for our problem.
  final bool freeUncheckedPhoto;

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
    targetName: 'Cacao tree',
    targetScientific: 'Theobroma cacao',
    families: kHuntFamilies['cacao']!,
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
    targetName: 'Swiss cheese plant',
    targetScientific: 'Monstera deliciosa',
    families: kHuntFamilies['monstera']!,
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
    targetName: 'Cutleaf coneflower',
    targetScientific: 'Rudbeckia laciniata',
    families: kHuntFamilies['kultapallo']!,
    accepted: kHuntAccepted['kultapallo']!,
    freeUncheckedPhoto: true,
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
    targetName: 'Grapevine',
    targetScientific: 'Vitis vinifera',
    families: kHuntFamilies['grape']!,
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
    targetName: 'White mustard',
    targetScientific: 'Sinapis alba',
    families: kHuntFamilies['mustard']!,
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
  bool _started = false;
  int _current = 0;
  bool _allDone = false;

  final List<_StopState> _states =
      List.filled(_kChallenges.length, _StopState.pending);
  final List<int> _points = List.filled(_kChallenges.length, 0);

  // Hints bought, per quest. Both cost points and both are confirmed first.
  final List<bool> _locationHint = List.filled(_kChallenges.length, false);
  final List<bool> _photoHint = List.filled(_kChallenges.length, false);

  // After three wrong answers, offer the name rather than let someone give up.
  final List<int> _wrongCounts = List.filled(_kChallenges.length, 0);
  final List<bool> _answerRevealed =
      List.filled(_kChallenges.length, false);

  final _textCtrl = TextEditingController();

  /// The photograph for this quest. Required to submit, and it can only have
  /// come from the camera screen below — nothing in this flow reads a file.
  Uint8List? _photo;
  String? _suggestion;
  bool _identifying = false;

  /// Whether the photograph passed the plant check. A photo of a shoe, or of
  /// the wrong plant, cannot be submitted — the identifier has to place it as
  /// the right species or at least the right family first.
  bool _photoAccepted = false;
  String? _photoRejection;

  /// Set when the visitor overrides a rejected photo check.
  ///
  /// The identifier is wrong often enough that it cannot be the last word on
  /// whether someone found a plant. It is safe to let them past because the
  /// typed name is the real gate: the override cannot get anyone through a
  /// quest they have not actually solved, only past a photo the AI misread.
  bool _photoOverridden = false;

  /// Rejected photos on this quest. The override only appears from the second
  /// one on: a first misread is usually fixed by stepping closer, and making
  /// the escape hatch the immediate path would make it the normal path.
  int _photoRejectCount = 0;

  /// Whether the last rejection was "there is no plant here". An empty frame
  /// is never overridable — the visitor is plainly not photographing a plant.
  bool _lastRejectWasNotAPlant = false;

  String? _wikiUrl;
  bool _loadingWiki = false;

  String? _feedback;
  bool _feedbackGood = false;

  // ── Recording + admin review ───────────────────────────────────────────────
  /// Storage path of the current photo, uploaded once and reused while the
  /// bytes are unchanged — re-uploading on every retyped answer is the one
  /// thing that would take this off the free tier.
  String? _photoPath;

  /// What the identifier made of the current photo, kept for the record.
  String _photoVerdict = '';
  String? _detectedName;

  /// The open review request, if the visitor has asked a human to look.
  String? _reviewId;
  ReviewRequest? _review;

  /// What an unconfirmed photo costs on the quest in play — zero where the
  /// identifier is known to struggle.
  int get _uncheckedCost => _kChallenges[_current].freeUncheckedPhoto
      ? 0
      : kUncheckedPhotoCost;

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

  // ── Photo ──────────────────────────────────────────────────────────────────

  /// Opens the in-app camera. There is deliberately no gallery or file option:
  /// a submission has to be a picture the visitor took standing in front of the
  /// plant, and the only way to produce one here is this screen.
  Future<void> _takePhoto() async {
    try {
      if (!await Permission.camera.request().isGranted) {
        if (mounted) {
          setState(() => _feedback = 'Camera permission is needed to submit.');
        }
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty || !mounted) return;
      final shot = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _HuntCamera(camera: preferredCamera(cams), all: cams),
        ),
      );
      if (shot == null || !mounted) return;

      // readAsBytes, not File(path): the same call works on web.
      final bytes = await shot.readAsBytes();
      setState(() {
        _photo = bytes;
        _identifying = true;
        _suggestion = null;
        _photoAccepted = false;
        _photoRejection = null;
        _photoOverridden = false;
        _photoPath = null;
        _reviewId = null;
        _review = null;
      });

      final info = await PlantIdentificationService.instance.identify(bytes);
      if (!mounted) return;

      final challenge = _kChallenges[_current];
      final verdict = checkPhotoPlant(
        isPlant: info.isPlant,
        detectedScientific: info.scientificName,
        detectedFamily: info.family,
        targetScientific: challenge.targetScientific,
        targetFamilies: challenge.families,
      );

      setState(() {
        _identifying = false;
        // The suggestion is a hint, never an answer: the identifier reads
        // leaves, and the hunt asks for what is written on the tag.
        _suggestion = (info.isPlant && info.scientificName != 'Unknown')
            ? info.scientificName
            : null;
        if (verdict != PhotoVerdict.accepted) _photoRejectCount++;
        _lastRejectWasNotAPlant = verdict == PhotoVerdict.notAPlant;
        _photoVerdict = verdict.name;
        _detectedName = info.isPlant ? info.scientificName : null;
        switch (verdict) {
          case PhotoVerdict.accepted:
            _photoAccepted = true;
            _photoRejection = null;
          case PhotoVerdict.notAPlant:
            _photoRejection =
                'No plant recognised in that photo. Get closer to a leaf, '
                'flower or fruit and take it again.';
          case PhotoVerdict.wrongPlant:
            _photoRejection =
                'That is a plant, but not the one this clue describes. Keep '
                'looking, then photograph the right one.';
          case PhotoVerdict.inconclusive:
            _photoRejection =
                'Could not place that one well enough to check it. Try a '
                'closer, sharper photo of a leaf or flower.';
        }
      });
    } catch (e) {
      // A hard failure — no network in a greenhouse, camera plugin error — is
      // not the visitor's fault. Accept the photo and say it was not checked,
      // rather than making a connection problem look like a wrong answer.
      if (mounted) {
        setState(() {
          _identifying = false;
          _photoAccepted = _photo != null;
          _photoRejection = null;
          _feedback = _photo == null
              ? 'Camera unavailable: $e'
              : 'Could not check your photo (offline?) — accepting it.';
          _feedbackGood = _photo != null;
        });
      }
    }
  }

  // ── Hints ──────────────────────────────────────────────────────────────────

  /// Every hint is quoted before it is bought. Returns true if the visitor
  /// accepted the cost.
  Future<bool> _confirmHintCost(String what, int cost) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E1E),
        title: const Text('Use a hint?',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 17)),
        content: Text(
          '$what costs you $cost points on this plant.\n\n'
          'You can still finish the quest and stay on the leaderboard — you '
          'will just score less for this one.',
          style: const TextStyle(color: Color(0xFF9CCC9F), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep trying',
                style: TextStyle(color: Color(0xFF81C784))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF231A00),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use it (−$cost)'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _buyLocationHint() async {
    if (!await _confirmHintCost('The location hint', kLocationHintCost)) return;
    if (mounted) setState(() => _locationHint[_current] = true);
  }

  Future<void> _buyPhotoHint() async {
    if (!await _confirmHintCost('A photo of the plant', kPhotoHintCost)) return;
    if (!mounted) return;
    setState(() => _loadingWiki = true);
    final url = await WikipediaImageService.instance.findImage(
      scientificName: _kChallenges[_current].targetScientific,
    );
    if (!mounted) return;
    setState(() {
      _loadingWiki = false;
      _wikiUrl = url;
      // Only charge for a hint that actually arrived.
      if (url != null) {
        _photoHint[_current] = true;
      } else {
        _feedback = 'Could not load the photo hint — you have not been charged.';
        _feedbackGood = false;
      }
    });
  }

  /// Uploads the current photo once and remembers where it went.
  Future<String?> _ensurePhotoUploaded() async {
    if (_photoPath != null || _photo == null) return _photoPath;
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return null;
    final path = await HuntSubmissionService.instance
        .uploadPhoto(_photo!, uid, _current);
    if (mounted) setState(() => _photoPath = path);
    return path;
  }

  /// Asks a person to look at a photo the identifier says holds no plant.
  ///
  /// Offered only for that verdict, and only after two tries: "no plant here"
  /// is the failure a visitor cannot argue with by retaking, and the one where
  /// the identifier is most often simply wrong about a real specimen.
  Future<void> _requestAdminReview() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _feedback = null);

    final path = await _ensurePhotoUploaded();
    final id = await HuntSubmissionService.instance.requestReview(
      uid: user.id,
      displayName: user.displayName,
      questIndex: _current,
      plantName: _kChallenges[_current].targetName,
      typedAnswer: _textCtrl.text.trim(),
      photoPath: path,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _feedback = 'Could not reach the garden team. Try again in a moment.';
        _feedbackGood = false;
      });
      return;
    }
    setState(() => _reviewId = id);

    // Watch for the decision so the screen reacts the moment it lands.
    HuntSubmissionService.instance.watchReview(id).listen((r) {
      if (!mounted || r == null) return;
      setState(() {
        _review = r;
        if (r.isApproved) {
          _photoAccepted = true;
          _photoRejection = null;
          _feedbackGood = true;
          _feedback = 'A garden staff member checked your photo and approved '
              'it. Type the name and submit.';
        } else if (r.isDeclined) {
          _photo = null;
          _photoPath = null;
          _photoAccepted = false;
          _reviewId = null;
          _feedbackGood = false;
          _feedback = 'The garden team could not see the plant in that photo. '
              'Take another one and try again.';
        }
      });
    });
  }

  // ── Judging ────────────────────────────────────────────────────────────────

  void _submit() {
    final typed = _textCtrl.text.trim();
    if (typed.isEmpty || _photo == null) return;
    if (!_photoAccepted && !_photoOverridden) return;

    final challenge = _kChallenges[_current];
    final score = scoreAnswer(typed, challenge.accepted);
    _record(challenge, typed, score);

    setState(() {
      if (score.isCorrect) {
        _states[_current] = _StopState.correct;
        _points[_current] = questPoints(
          answerScore: score.points,
          usedLocationHint: _locationHint[_current],
          usedPhotoHint: _photoHint[_current],
          answerRevealed: _answerRevealed[_current],
          uncheckedPhoto: _photoOverridden,
          uncheckedPhotoCost: _uncheckedCost,
        );
        _feedbackGood = true;
        final spent = (_locationHint[_current] ? kLocationHintCost : 0) +
            (_photoHint[_current] ? kPhotoHintCost : 0) +
            (_photoOverridden ? _uncheckedCost : 0);
        _feedback = _answerRevealed[_current]
            ? 'Found it. No points for this one — you had the answer.'
            : spent > 0
                ? 'Found it! ${score.points} − $spent = '
                    '+${_points[_current]} points'
                : 'Found it! +${_points[_current]} points';
        // Fires after this frame so the popup opens over a card that already
        // shows the result.
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _questPassed(_points[_current]));
      } else {
        _states[_current] = _StopState.wrong;
        _wrongCounts[_current]++;
        _feedbackGood = false;
        // Says nothing about what the plant is, not even how close the guess
        // was — "warmer" would narrow it down.
        _feedback = 'Not this one. Read the tag on the plant and try again, '
            'or take a hint below.';
      }
    });
  }

  /// Two seconds of "you passed", then the next quest.
  ///
  /// Auto-advancing rather than leaving a Next button: the visitor has both
  /// hands full of phone and plant, and one fewer tap between quests is one
  /// fewer reason to stop walking.
  Future<void> _questPassed(int banked) async {
    final last = _current == _kChallenges.length - 1;
    final next = _current + 2; // 1-based number of the quest coming up

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded,
                      color: Colors.greenAccent, size: 40)
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              const Text(
                'SPECIMEN VERIFIED',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '+$banked pts committed',
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                last
                    ? 'All records logged · compiling your badge…'
                    : 'Record logged · loading quest $next of ${_kChallenges.length}…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF9CCC9F), fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the popup
    if (!mounted) return;
    _nextChallenge();
  }

  /// Keeps the attempt — photo, typed name, verdict, points — whether it was
  /// right or wrong. A wrong answer is the interesting one when the garden
  /// later asks what people thought its plants were called, and it cannot be
  /// recovered afterwards if it was never written down.
  Future<void> _record(
      _Challenge challenge, String typed, AnswerScore score) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final path = await _ensurePhotoUploaded();
    await HuntSubmissionService.instance.recordAttempt(
      uid: user.id,
      displayName: user.displayName,
      questIndex: _current,
      plantName: challenge.targetName,
      typedAnswer: typed,
      correct: score.isCorrect,
      points: score.isCorrect
          ? questPoints(
              answerScore: score.points,
              usedLocationHint: _locationHint[_current],
              usedPhotoHint: _photoHint[_current],
              answerRevealed: _answerRevealed[_current],
              uncheckedPhoto: _photoOverridden,
              uncheckedPhotoCost: _uncheckedCost,
            )
          : 0,
      photoVerdict: _review?.isApproved == true ? 'adminApproved' : _photoVerdict,
      detectedName: _detectedName,
      photoPath: path,
      usedLocationHint: _locationHint[_current],
      usedPhotoHint: _photoHint[_current],
      uncheckedPhoto: _photoOverridden,
      adminApproved: _review?.isApproved == true,
    );
  }

  void _resetQuestState() {
    _textCtrl.clear();
    _photo = null;
    _suggestion = null;
    _photoAccepted = false;
    _photoRejection = null;
    _photoOverridden = false;
    _photoRejectCount = 0;
    _lastRejectWasNotAPlant = false;
    _photoPath = null;
    _photoVerdict = '';
    _detectedName = null;
    _reviewId = null;
    _review = null;
    _wikiUrl = null;
    _feedback = null;
  }

  void _nextChallenge() {
    if (_current < _kChallenges.length - 1) {
      setState(() {
        _current++;
        _resetQuestState();
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

  void _skipChallenge() {
    setState(() {
      _states[_current] = _StopState.wrong;
      _points[_current] = 0;
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
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HuntLeaderboardScreen())),
          ),
        ],
      ),
      body: !_started
          ? _buildIntro()
          : _allDone
              ? _buildBadge()
              : _buildHunt(),
    );
  }

  // ── Intro ──────────────────────────────────────────────────────────────────

  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore the greenhouses and outdoor garden to track down '
            '5 mystery plants. Each quest gives you a clue, but no plant name. '
            'Can you figure it out?',
            style: TextStyle(
                color: Color(0xFFE8F5E9), fontSize: 14.5, height: 1.55),
          ),
          const SizedBox(height: 18),

          _introStep(Icons.search_rounded,
              'Read the clue and look for the matching plant.'),
          // Reworded from "or": a submission needs both, so the instructions
          // have to say both or the first submit button looks broken.
          _introStep(Icons.photo_camera_rounded,
              'Take a photo of the plant AND type its name to submit your '
              'answer. The photo must be taken with the camera here.'),
          _introStep(Icons.explore_outlined,
              'Need help? Tap Show where to look for a hint.'),
          _introStep(Icons.flag_rounded,
              'Complete all 5 quests to finish the hunt.'),
          _introStep(Icons.leaderboard_rounded,
              'Earn points and see how you rank on the leaderboard.'),

          const SizedBox(height: 10),
          const Text(
            'Keep your eyes open. The clues may point to unusual features, '
            'surprising uses, or fascinating plant stories.',
            style: TextStyle(
                color: Color(0xFF9CCC9F),
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 22),
          _pointsPanel(),

          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Quest'),
            onPressed: () => setState(() => _started = true),
          ),
        ],
      ),
    );
  }

  Widget _introStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF66BB6A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFCFE8D2), fontSize: 13.5, height: 1.5)),
          ),
        ],
      ),
    );
  }

  /// The point rules, stated in one place and shown both here and in the quest.
  Widget _pointsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.stars_rounded, size: 16, color: Color(0xFFFFD54F)),
            SizedBox(width: 6),
            Text('HOW POINTS WORK',
                style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1)),
          ]),
          const SizedBox(height: 10),
          _pointRow('Each plant is worth up to', '$kMaxQuestPoints pts'),
          _pointRow('Exact name from the tag', 'full points'),
          _pointRow('Close spelling', 'slightly fewer'),
          _pointRow('Hint 1 — where to look', '−$kLocationHintCost pts'),
          _pointRow('Hint 2 — photo of the plant', '−$kPhotoHintCost pts'),
          _pointRow('Photo we cannot confirm', '−$kUncheckedPhotoCost pts'),
          _pointRow('Being told the answer', '0 pts'),
          const Divider(color: Color(0xFF2E7D32), height: 18),
          const Text(
            'Wrong answers cost nothing. Your photo has to be the right plant '
            '— if we cannot confirm it, you can still submit, but it costs.',
            style: TextStyle(
                color: Color(0xFF9CCC9F), fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _pointRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFFCFE8D2), fontSize: 12.5)),
          ),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Quest ──────────────────────────────────────────────────────────────────

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
                // Nothing in this header may hint at which plant this is.
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
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 18),
          _buildAnswerBlock(state),
          const SizedBox(height: 16),
          _buildHints(challenge, state),

          if (_feedback != null) ...[
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _feedbackGood
                    ? Colors.green[900]!.withOpacity(0.4)
                    : Colors.red[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _feedbackGood
                        ? Colors.greenAccent
                        : Colors.red[400]!),
              ),
              child: Row(
                children: [
                  Icon(_feedbackGood ? Icons.check_circle : Icons.close,
                      color: _feedbackGood
                          ? Colors.greenAccent
                          : Colors.red[400]!,
                      size: 20),
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
          ],

          const SizedBox(height: 16),
          _buildActionButton(state, challenge),
        ],
      ),
    );
  }

  Widget _buildAnswerBlock(_StopState state) {
    final done = state == _StopState.correct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('YOUR ANSWER',
            style: TextStyle(
                color: Color(0xFF81C784),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        const Text(
          'Both are needed: a photo you take here, and the name from the '
          'plant’s tag. Finnish, Latin or the everyday name all count, and '
          'close spelling is fine.',
          style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 12),

        // ── 1. Photo ───────────────────────────────────────────────────────
        GestureDetector(
          onTap: done ? null : _takePhoto,
          child: Container(
            height: _photo == null ? 92 : 200,
            decoration: BoxDecoration(
              color: const Color(0xFF13301A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _photo == null
                      ? const Color(0xFF2E7D32)
                      : _photoRejection != null
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF66BB6A),
                  width: _photoRejection != null ? 1.5 : 1),
              image: _photo == null
                  ? null
                  : DecorationImage(
                      image: MemoryImage(_photo!), fit: BoxFit.cover),
            ),
            child: _photo != null
                ? null
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_rounded,
                            color: Color(0xFF81C784), size: 26),
                        SizedBox(height: 6),
                        Text('1 · Take a photo of the plant',
                            style: TextStyle(
                                color: Color(0xFF81C784), fontSize: 13.5)),
                        SizedBox(height: 2),
                        Text('Camera only — saved pictures are not accepted',
                            style: TextStyle(
                                color: Color(0xFF4A7A50), fontSize: 11)),
                      ],
                    ),
                  ),
          ),
        ),
        if (_photo != null && !done)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.refresh, size: 14, color: Color(0xFF66BB6A)),
              label: const Text('Retake',
                  style: TextStyle(color: Color(0xFF66BB6A), fontSize: 12)),
            ),
          ),

        if (_photoRejection != null && !_identifying)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1414),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF5350)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.report_gmailerrorred_rounded,
                    size: 16, color: Color(0xFFEF5350)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_photoRejection!,
                          style: const TextStyle(
                              color: Color(0xFFFFCDD2),
                              fontSize: 12.5,
                              height: 1.4)),
                      // "No plant here" is the verdict a visitor cannot argue
                      // with by retaking, and the one the identifier most often
                      // gets wrong about a real specimen. After two tries, a
                      // person looks at it instead.
                      if (_lastRejectWasNotAPlant && _photoRejectCount >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _reviewId != null
                              ? const Row(children: [
                                  SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFFFFD54F))),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        'Sent to the garden team. Keep this '
                                        'screen open — you will hear back in a '
                                        'moment.',
                                        style: TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontSize: 12,
                                            height: 1.35)),
                                  ),
                                ])
                              : GestureDetector(
                                  onTap: _requestAdminReview,
                                  child: const Text(
                                    'Sure there is a plant here? '
                                    'Ask a garden staff member to check →',
                                    style: TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFFFFD54F),
                                    ),
                                  ),
                                ),
                        ),

                      // The escape hatch, deliberately narrow. Never for an
                      // empty frame, never on the first try, never free — a
                      // free one would let anyone who knows the name submit a
                      // photo of any leaf in the garden.
                      if (!_lastRejectWasNotAPlant && _photoRejectCount >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: GestureDetector(
                            onTap: () async {
                              // No dialog when it is free — there is nothing
                              // to weigh up, and this plant needs the hatch.
                              final ok = _uncheckedCost == 0 ||
                                  await _confirmHintCost(
                                      'Submitting a photo we could not confirm',
                                      _uncheckedCost);
                              if (ok && mounted) {
                                setState(() {
                                  _photoOverridden = true;
                                  _photoRejection = null;
                                });
                              }
                            },
                            child: Text(
                              _uncheckedCost == 0
                                  ? 'Sure this is the right plant? '
                                      'Submit it anyway (no cost) →'
                                  : 'Sure this is the right plant? '
                                      'Submit unchecked (−$_uncheckedCost pts) →',
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFFFD54F),
                              ),
                            ),
                          ),
                        )
                      else if (!_lastRejectWasNotAPlant)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Step closer and try once more. If it still will '
                            'not confirm, you will be able to submit it '
                            'anyway.',
                            style: TextStyle(
                                color: Color(0xFF9CCC9F),
                                fontSize: 11.5,
                                height: 1.35),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (_photoOverridden && !_identifying)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: Color(0xFFFFD54F)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    _uncheckedCost == 0
                        ? 'Submitting unchecked — no cost on this plant.'
                        : 'Submitting unchecked — '
                            '−$_uncheckedCost pts on this plant.',
                    style: const TextStyle(
                        color: Color(0xFFFFD54F), fontSize: 12)),
              ),
            ]),
          ),

        if (_photoAccepted && !_identifying)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [
              Icon(Icons.verified_rounded, size: 15, color: Colors.greenAccent),
              SizedBox(width: 6),
              Text('Photo checked — this is the right plant.',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ]),
          ),

        if (_identifying)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: [
              SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF81C784))),
              SizedBox(width: 8),
              Text('Checking your photo…',
                  style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12)),
            ]),
          ),

        if (_suggestion != null && !_identifying)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13301A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E7D32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Color(0xFF81C784)),
                  SizedBox(width: 6),
                  Text('PROBABLY',
                      style: TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                ]),
                const SizedBox(height: 6),
                SelectableText(_suggestion!,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text(
                  'A guess from your photo, not the answer. Check it against '
                  'the plant’s tag, then type what the tag says.',
                  style: TextStyle(
                      color: Color(0xFF6E8A72), fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // ── 2. Name ────────────────────────────────────────────────────────
        TextField(
          controller: _textCtrl,
          style: const TextStyle(color: Color(0xFFE8F5E9)),
          enabled: !done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '2 · Type the name from the tag…',
            prefixIcon:
                Icon(Icons.local_offer_outlined, color: Color(0xFF4CAF50)),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildHints(_Challenge challenge, _StopState state) {
    if (state == _StopState.correct) return const SizedBox.shrink();

    // The photo hint unlocks once a first answer has missed — until then the
    // clue deserves a fair try.
    final photoUnlocked = _wrongCounts[_current] > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A4A2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HINTS — EACH ONE COSTS POINTS',
              style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1)),
          const SizedBox(height: 10),

          // ── Hint 1 — location ────────────────────────────────────────────
          if (_locationHint[_current])
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('📍 ${challenge.whereToLook}',
                  style: const TextStyle(
                      color: Color(0xFF66BB6A), fontSize: 12.5, height: 1.5)),
            )
          else
            _hintButton(
              icon: Icons.explore_outlined,
              label: 'Show where to look',
              cost: kLocationHintCost,
              onTap: _buyLocationHint,
            ),

          // ── Hint 2 — a photo of the plant ────────────────────────────────
          if (_photoHint[_current] && _wikiUrl != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _wikiUrl!,
                  width: double.infinity,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          else if (photoUnlocked)
            _hintButton(
              icon: Icons.image_outlined,
              label: _loadingWiki
                  ? 'Loading photo…'
                  : 'Show a photo of the plant',
              cost: kPhotoHintCost,
              onTap: _loadingWiki ? null : _buyPhotoHint,
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'A photo of the plant unlocks as a second hint after your '
                'first attempt.',
                style: TextStyle(color: Color(0xFF4A7A50), fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hintButton({
    required IconData icon,
    required String label,
    required int cost,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFFD54F),
        side: const BorderSide(color: Color(0xFF8D6E00)),
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 0),
      ),
      icon: Icon(icon, size: 16),
      label: Text('$label  (−$cost pts)',
          style: const TextStyle(fontSize: 13)),
      onPressed: onTap,
    );
  }

  Widget _progressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_kChallenges.length, (i) {
        final done = _states[i] == _StopState.correct;
        final isActive = i == _current;
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
                            fontWeight: FontWeight.w700)),
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
                      '${LanguageService.instance.strings.tapToKnowTheAnswer}  (0 pts)'),
                  onPressed: () async {
                    if (await _confirmHintCost(
                        'Being told the answer', kMaxQuestPoints)) {
                      if (mounted) {
                        setState(() => _answerRevealed[_current] = true);
                      }
                    }
                  },
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

    final hasPhoto = _photo != null && (_photoAccepted || _photoOverridden);
    final hasName = _textCtrl.text.trim().isNotEmpty;
    final canSubmit = hasPhoto && hasName;
    return Column(
      children: [
        if (!canSubmit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _photoRejection != null
                  ? 'Retake the photo to submit.'
                  : !hasPhoto && !hasName
                      ? 'Take a photo and type the name to submit.'
                      : !hasPhoto
                          ? 'Take a photo of the plant to submit.'
                          : 'Type the name from the tag to submit.',
              style: const TextStyle(color: Color(0xFF6E8A72), fontSize: 12),
            ),
          ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canSubmit ? const Color(0xFF2E7D32) : const Color(0xFF1A2E1E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.send_rounded),
          label: Text(LanguageService.instance.strings.submitAnswer,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          onPressed: canSubmit ? _submit : null,
        ),
      ],
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
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HuntLeaderboardScreen())),
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

// ─── Camera ───────────────────────────────────────────────────────────────────

/// The only way a photograph enters the hunt.
///
/// There is no gallery picker and no file input anywhere in this flow, so a
/// submitted picture is necessarily one the visitor took here, with the app
/// open, in front of the plant. That is the verification — an image saved from
/// the internet has no route in.
class _HuntCamera extends StatefulWidget {
  const _HuntCamera({required this.camera, required this.all});
  final CameraDescription camera;
  final List<CameraDescription> all;

  @override
  State<_HuntCamera> createState() => _HuntCameraState();
}

class _HuntCameraState extends State<_HuntCamera> {
  CameraController? _controller;
  late CameraDescription _active = widget.camera;

  @override
  void initState() {
    super.initState();
    _open(widget.camera);
  }

  Future<void> _open(CameraDescription cam) async {
    await _controller?.dispose();
    if (mounted) setState(() => _controller = null);
    _active = cam;
    final c =
        CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    await c.initialize();
    if (mounted) setState(() => _controller = c);
  }

  Future<void> _switch() async {
    final next = nextCamera(widget.all, _active);
    if (next != null) await _open(next);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFF66BB6A)),
        title: const Text('Photograph the plant',
            style: TextStyle(color: Color(0xFFE8F5E9), fontSize: 16)),
      ),
      body: c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Center(child: ZoomableCameraPreview(controller: c)),
                if (hasMultipleCameras(widget.all))
                  Positioned(
                    right: 24,
                    bottom: 52,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Switch camera',
                        icon: Icon(Icons.flip_camera_android_rounded,
                            color: isFront(_active)
                                ? const Color(0xFFFFD54F)
                                : Colors.white),
                        onPressed: _switch,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        final f = await c.takePicture();
                        if (mounted) Navigator.pop(context, f);
                      } catch (_) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border:
                            Border.all(color: const Color(0xFF66BB6A), width: 4),
                      ),
                    ),
                  ),
                ),
              ],
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: rows.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(2, 8, 2, 14),
                  child: Text(
                    'Ranked by plants found. Points break a tie.',
                    style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12),
                  ),
                );
              }
              final i = index - 1;
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
                  color:
                      mine ? const Color(0xFF16301D) : const Color(0xFF111F16),
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
                          const SizedBox(height: 3),
                          // Five pips: how far round the garden they got, at a
                          // glance and without reading a number.
                          Row(
                            children: List.generate(
                              _kChallenges.length,
                              (q) => Container(
                                width: 13,
                                height: 5,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  color: q < r.solved
                                      ? Colors.greenAccent
                                      : const Color(0xFF2A4A2F),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quests found is what the board ranks on, so it is the
                    // number people see; points only separate equal hunters.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${r.solved}/${_kChallenges.length}',
                            style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        Text('quests · ${r.total} pts',
                            style: const TextStyle(
                                color: Color(0xFF4A7A50), fontSize: 10.5)),
                      ],
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
