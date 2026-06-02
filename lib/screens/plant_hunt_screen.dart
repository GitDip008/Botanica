import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/badge_service.dart';
import '../services/chat_service.dart';
import '../services/gemini_proxy.dart';
import '../services/language_service.dart';
import '../services/plant_identification_service.dart';
import '../services/usage_tracking_service.dart';

// ─── Data ─────────────────────────────────────────────────────────────────────

class _Challenge {
  final String questNumber;
  final String emoji;
  final String familyName;
  final String familyCommon;
  final String clue;
  final String whereToLook;
  final String targetName; // used only for Gemini validation
  final String targetScientific;

  const _Challenge({
    required this.questNumber,
    required this.emoji,
    required this.familyName,
    required this.familyCommon,
    required this.clue,
    required this.whereToLook,
    required this.targetName,
    required this.targetScientific,
  });
}

const _kChallenges = [
  _Challenge(
    questNumber: '1',
    emoji: '🌼',
    familyName: 'Asteraceae',
    familyCommon: 'Daisy / Composite family',
    clue: 'I have tiny white petals arranged around a bright yellow button in the centre. '
        'When you gently crush one of my feathery leaves, you will smell something like apples. '
        'People have been making tea from me for thousands of years to soothe upset tummies.',
    whereToLook: '📍 Medicinal & Economic Plants section — the fenced area. '
        'Open the wooden gate and look in the border beds.',
    targetName: 'Chamomile',
    targetScientific: 'Matricaria chamomilla',
  ),
  _Challenge(
    questNumber: '2',
    emoji: '🦜',
    familyName: 'Strelitziaceae',
    familyCommon: 'Bird of Paradise family',
    clue: 'I live inside the warm tropical pyramid greenhouse where it is always 26 °C. '
        'My flower looks exactly like a colourful bird in mid-flight — '
        'bright orange "wings" and a vivid blue "beak". I am named after an exotic bird.',
    whereToLook: '📍 Romeo Greenhouse — the larger glass pyramid near the entrance. '
        'Look for the flower at about eye height in the central display bed.',
    targetName: 'Bird of Paradise',
    targetScientific: 'Strelitzia reginae',
  ),
  _Challenge(
    questNumber: '3',
    emoji: '🌸',
    familyName: 'Rosaceae',
    familyCommon: 'Rose family',
    clue: 'I am Finland\'s national flower! I grow on a rocky mountain mound in the garden. '
        'I have exactly 8 bright white petals — unusual, since most rose family flowers have 5. '
        'In autumn I turn into a fluffy silver ball of seeds that floats on the wind.',
    whereToLook: '📍 Fennoscandian Mountain section — the rocky raised mound. '
        'I form a low, creeping mat on the ground between the boulders.',
    targetName: 'Mountain Avens',
    targetScientific: 'Dryas octopetala',
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PlantHuntScreen extends StatefulWidget {
  const PlantHuntScreen({super.key});

  @override
  State<PlantHuntScreen> createState() => _PlantHuntScreenState();
}

enum _StopState { pending, checking, correct, wrong }

class _PlantHuntScreenState extends State<PlantHuntScreen> {
  int _current = 0; // which challenge we're on
  final List<_StopState> _states = List.filled(3, _StopState.pending);
  String? _feedback; // Gemini one-liner
  bool _allDone = false;

  // Wrong-attempt tracking — after 3 wrong, offer "reveal answer"
  final List<int> _wrongCounts = List.filled(3, 0);
  final List<bool> _answerRevealed = List.filled(3, false);

  // Camera
  CameraController? _cam;
  bool _camReady = false;
  String? _capturedPath;

  // Text input
  final _textCtrl = TextEditingController();
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    UsageTrackingService.instance.log(UsageTrackingService.featurePlantHunt);
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cam = CameraController(cameras.first, ResolutionPreset.medium,
        enableAudio: false);
    await _cam!.initialize();
    if (mounted) setState(() => _camReady = true);
  }

  @override
  void dispose() {
    _cam?.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Camera capture ─────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_cam == null || !_camReady) return;
    try {
      final file = await _cam!.takePicture();
      setState(() => _capturedPath = file.path);
    } catch (_) {}
  }

  void _retakePhoto() => setState(() => _capturedPath = null);

  // ── Validation ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final challenge = _kChallenges[_current];
    final typedAnswer = _textCtrl.text.trim();
    if (typedAnswer.isEmpty && _capturedPath == null) return;

    setState(() {
      _states[_current] = _StopState.checking;
      _feedback = null;
    });

    try {
      bool isCorrect;
      String msg;

      if (_capturedPath != null) {
        // ── Photo submission → PlantNet (free) with Gemini fallback ─────
        final bytes = await File(_capturedPath!).readAsBytes();
        final result = await PlantIdentificationService.instance.validateHunt(
          imageBytes: bytes,
          targetCommonName: challenge.targetName,
          targetScientific: challenge.targetScientific,
          targetFamily: challenge.familyName,
        );
        isCorrect = result.isCorrect;
        msg = result.feedback;
      } else {
        // ── Text-only submission → Groq (free) with Gemini fallback ─────
        final cloudReply = await ChatService.instance.cloud.completeText(
          systemPrompt:
              'You are a friendly botanist helping a child on a plant scavenger hunt at Oulu Botanical Garden. Always reply in EXACTLY two lines: line 1 is just the word CORRECT or WRONG, line 2 is one short encouraging sentence (max 12 words).',
          userPrompt:
              'The child is looking for: ${challenge.targetName} (${challenge.targetScientific}). '
              'Plant family: ${challenge.familyName}. '
              'The child answered: "$typedAnswer". '
              'Is their answer correct (same plant, common name, scientific name, or close enough)? '
              'Be generous — accept common names, partial matches, or the family name.',
          maxTokens: 60,
        );

        String? reply = cloudReply;
        if (reply == null) {
          // Gemini fallback via Cloud Function proxy
          final prompt =
              'You are a friendly botanist helping a child on a plant scavenger hunt. '
              'The child is looking for ${challenge.targetName} (${challenge.targetScientific}). '
              'The child answered: "$typedAnswer". '
              'Reply with exactly two lines: CORRECT or WRONG, then one short sentence (max 12 words).';
          reply = await GeminiProxy.instance.text(
            prompt: prompt,
            model: 'gemini-2.5-flash',
          );
        }

        final lines =
            reply.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final verdict =
            lines.isNotEmpty ? lines[0].trim().toUpperCase() : '';
        msg = lines.length > 1 ? lines[1].trim() : '';
        isCorrect = verdict.contains('CORRECT');
      }

      if (mounted) {
        setState(() {
          _states[_current] = isCorrect ? _StopState.correct : _StopState.wrong;
          if (!isCorrect) _wrongCounts[_current]++;
          _feedback = msg.isNotEmpty
              ? msg
              : isCorrect
                  ? 'Well done, plant detective! 🌿'
                  : 'Not quite — look for more clues!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _states[_current] = _StopState.wrong;
          _feedback = 'Could not check — try again! (${e.toString().split('\n').first})';
        });
      }
    }
  }

  void _nextChallenge() {
    if (_current < 2) {
      setState(() {
        _current++;
        _capturedPath = null;
        _textCtrl.clear();
        _showHint = false;
        _feedback = null;
        _states[_current] = _StopState.pending;
      });
    } else {
      // Award persistent badge for completing the hunt — survives sign-outs
      // and shows up later on the profile / chat shelf.
      BadgeService.instance.award('plant_hunt_completed');
      setState(() => _allDone = true);
    }
  }

  void _retryChallenge() {
    setState(() {
      _states[_current] = _StopState.pending;
      _capturedPath = null;
      _textCtrl.clear();
      _feedback = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
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
                color: Color(0xFFE8F5E9),
                fontWeight: FontWeight.bold)),
      ),
      body: _allDone ? _buildBadge() : _buildHunt(),
    );
  }

  // ── Progress dots + challenge ──────────────────────────────────────────────

  Widget _buildHunt() {
    final challenge = _kChallenges[_current];
    final state = _states[_current];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final s = _states[i];
              final isActive = i == _current;
              Color dotColor;
              IconData? icon;
              if (s == _StopState.correct) {
                dotColor = Colors.greenAccent;
                icon = Icons.check;
              } else if (i < _current) {
                dotColor = Colors.greenAccent;
                icon = Icons.check;
              } else if (isActive) {
                dotColor = const Color(0xFF66BB6A);
                icon = null;
              } else {
                dotColor = const Color(0xFF2E7D32).withOpacity(0.3);
                icon = null;
              }
              return AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: isActive ? 36 : 28,
                height: isActive ? 36 : 28,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(isActive ? 0.3 : 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: isActive ? 2 : 1),
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: dotColor, size: 14)
                      : Text('${i + 1}',
                          style: TextStyle(
                              color: dotColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // Quest card header
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
                Row(
                  children: [
                    Text(challenge.emoji,
                        style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              LanguageService.instance.strings
                                  .questNumber(challenge.questNumber),
                              style: const TextStyle(
                                  color: Color(0xFF66BB6A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(challenge.familyName,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text(challenge.familyCommon,
                              style: const TextStyle(
                                  color: Color(0xFF4CAF50), fontSize: 12)),
                        ],
                      ),
                    ),
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
                const SizedBox(height: 6),
                Text(challenge.clue,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 13,
                        height: 1.6)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _showHint = !_showHint),
                  child: Row(children: [
                    Icon(
                      _showHint
                          ? Icons.expand_less
                          : Icons.explore_outlined,
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
                    child: Text(challenge.whereToLook,
                        style: const TextStyle(
                            color: Color(0xFF66BB6A),
                            fontSize: 12,
                            height: 1.5)),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          const SizedBox(height: 16),

          // Camera area
          _buildCameraArea(),

          const SizedBox(height: 14),

          // OR text input
          if (_capturedPath == null) ...[
            const Row(children: [
              Expanded(child: Divider(color: Color(0xFF2E7D32))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or type the plant name',
                    style: TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 11)),
              ),
              Expanded(child: Divider(color: Color(0xFF2E7D32))),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _textCtrl,
              style: const TextStyle(color: Color(0xFFE8F5E9)),
              decoration: const InputDecoration(
                hintText: 'e.g. Chamomile, Matricaria...',
                prefixIcon: Icon(Icons.edit, color: Color(0xFF4CAF50)),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 14),
          ],

          // Feedback banner
          if (_feedback != null)
            AnimatedContainer(
              duration: 300.ms,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: state == _StopState.correct
                    ? Colors.green[900]!.withOpacity(0.4)
                    : Colors.red[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state == _StopState.correct
                      ? Colors.greenAccent
                      : Colors.red[400]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state == _StopState.correct
                        ? Icons.check_circle
                        : Icons.close,
                    color: state == _StopState.correct
                        ? Colors.greenAccent
                        : Colors.red[400]!,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_feedback!,
                        style: TextStyle(
                            color: state == _StopState.correct
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontSize: 14,
                            height: 1.4)),
                  ),
                ],
              ),
            ),

          // Action buttons
          _buildActionButton(state, challenge),
        ],
      ),
    );
  }

  // ── Camera widget ──────────────────────────────────────────────────────────

  Widget _buildCameraArea() {
    if (_capturedPath != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(File(_capturedPath!),
                height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _retakePhoto,
            icon: const Icon(Icons.refresh, color: Color(0xFF66BB6A), size: 16),
            label: Text(LanguageService.instance.strings.retakePhoto,
                style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 12)),
          ),
        ],
      );
    }

    if (!_camReady || _cam == null) {
      return GestureDetector(
        onTap: _initCamera,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF2E7D32), style: BorderStyle.solid),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, color: Color(0xFF4CAF50), size: 36),
              const SizedBox(height: 8),
              Text(LanguageService.instance.strings.tapToOpenCamera,
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
              Text(LanguageService.instance.strings.takeAPhotoOfThePlant,
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: _cam!.value.aspectRatio,
            child: CameraPreview(_cam!),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A2E1E),
            foregroundColor: const Color(0xFF66BB6A),
            side: const BorderSide(color: Color(0xFF2E7D32)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.camera, size: 18),
          label: Text(LanguageService.instance.strings.takePhoto,
              style: const TextStyle(fontSize: 13)),
          onPressed: _capture,
        ),
      ],
    );
  }

  // ── Action button ──────────────────────────────────────────────────────────

  Widget _buildActionButton(_StopState state, _Challenge challenge) {
    if (state == _StopState.checking) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const CircularProgressIndicator(color: Color(0xFF66BB6A)),
              const SizedBox(height: 8),
              Text(LanguageService.instance.strings.checkingYourAnswer,
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (state == _StopState.correct) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          _current < 2
              ? LanguageService.instance.strings.nextQuest
              : LanguageService.instance.strings.claimYourBadge,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: _nextChallenge,
      );
    }

    if (state == _StopState.wrong) {
      final challenge = _kChallenges[_current];
      final showReveal = _wrongCounts[_current] >= 3;
      return Column(
        children: [
          // After 3 wrong attempts → offer to reveal the answer
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
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            color: Color(0xFFFFD54F), size: 16),
                        const SizedBox(width: 6),
                        Text(LanguageService.instance.strings.theAnswerIs,
                            style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${challenge.targetName} (${challenge.targetScientific})',
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageService.instance.strings.goFindItToContinue,
                      style: const TextStyle(
                          color: Color(0xFF81C784), fontSize: 12),
                    ),
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
                  label: Text(LanguageService.instance.strings.tapToKnowTheAnswer),
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
        ],
      );
    }

    // Pending state
    final canSubmit =
        _capturedPath != null || _textCtrl.text.trim().isNotEmpty;
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            canSubmit ? const Color(0xFF2E7D32) : const Color(0xFF1A2E1E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.send_rounded),
      label: Text(LanguageService.instance.strings.submitAnswer,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      onPressed: canSubmit ? _submit : null,
    );
  }

  // ── Badge screen ───────────────────────────────────────────────────────────

  Widget _buildBadge() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
        child: Column(
          children: [
            // Badge container
            Container(
              padding: const EdgeInsets.all(28),
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
                  const Text('🏆', style: TextStyle(fontSize: 72))
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 16),
                  const Text(
                    'PLANT DETECTIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Official Badge',
                    style: TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 13,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2E7D32)),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BadgeStar(emoji: '🌼', label: 'Chamomile'),
                      _BadgeStar(emoji: '🦜', label: 'Bird of\nParadise'),
                      _BadgeStar(emoji: '🌸', label: 'Mountain\nAvens'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF2E7D32)),
                  const SizedBox(height: 14),
                  const Text(
                    'Oulu Botanical Garden',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.card_giftcard,
                      color: Colors.greenAccent, size: 32),
                  SizedBox(height: 10),
                  Text(
                    'Show this badge to a garden staff member\nat the info desk for a small surprise! 🎁',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 14,
                        height: 1.6),
                  ),
                ],
              ),
            ).animate().slideY(begin: 0.2, delay: 300.ms, duration: 400.ms),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.home),
              label: Text(LanguageService.instance.strings.backToHome,
                  style: const TextStyle(fontSize: 14)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeStar extends StatelessWidget {
  final String emoji;
  final String label;

  const _BadgeStar({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.15),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.greenAccent.withOpacity(0.6)),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF66BB6A), fontSize: 10),
            textAlign: TextAlign.center),
      ],
    );
  }
}
