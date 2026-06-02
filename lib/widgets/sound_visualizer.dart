import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../services/language_service.dart';

class SoundVisualizer extends StatefulWidget {
  const SoundVisualizer({super.key});

  @override
  State<SoundVisualizer> createState() => _SoundVisualizerState();
}

class _SoundVisualizerState extends State<SoundVisualizer>
    with TickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _pcmSub;

  double _currentDb = 0;
  double _smoothDb  = 0; // exponential moving-average for smooth visuals

  bool _isListening = false;
  bool _hasPermission = false;
  bool _requesting = false;
  String? _errorMsg;
  Timer? _noDataTimer;

  // ── Wave animation ─────────────────────────────────────────────────────────
  // A Ticker gives raw elapsed milliseconds that grow forever — no reset,
  // no phase jump.  The ValueNotifier lets AnimatedBuilder rebuild only the
  // CustomPaint widget, not the whole tree.
  late final ValueNotifier<double> _elapsedSec = ValueNotifier(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _elapsedSec.value = elapsed.inMicroseconds / 1e6;
    });
    _ticker.start();

    _checkAndStart();
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _checkAndStart() async {
    if (_requesting) return;
    setState(() { _requesting = true; _errorMsg = null; });

    var status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      if (mounted) setState(() { _hasPermission = false; _requesting = false; _errorMsg = 'permanently_denied'; });
      return;
    }
    if (!status.isGranted) status = await Permission.microphone.request();
    if (!mounted) return;

    if (status.isGranted) {
      setState(() { _hasPermission = true; _requesting = false; });
      await _startListening();
    } else {
      setState(() { _hasPermission = false; _requesting = false;
        _errorMsg = status.isPermanentlyDenied ? 'permanently_denied' : 'denied';
      });
    }
  }

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    await _pcmSub?.cancel();
    _pcmSub = null;
    _noDataTimer?.cancel();

    try {
      if (await _recorder.isRecording()) await _recorder.stop();

      final Stream<List<int>> pcmStream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );

      _noDataTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isListening) setState(() => _errorMsg = 'no_data');
      });

      _pcmSub = pcmStream.listen(
        (List<int> pcmBytes) {
          if (!mounted) return;
          _noDataTimer?.cancel();
          final db = _rmsToDb(pcmBytes);
          setState(() {
            _currentDb = db;
            // Smooth: slow rise, fast fall for natural feel
            _smoothDb = db > _smoothDb
                ? _smoothDb * 0.6 + db * 0.4
                : _smoothDb * 0.85 + db * 0.15;
            _isListening = true;
            _errorMsg = null;
          });
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() { _isListening = false; _errorMsg = e.toString(); });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _hasPermission) _startListening();
          });
        },
        onDone: () {
          if (mounted && _hasPermission && !_isListening) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted && _hasPermission) _startListening();
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (mounted) setState(() { _isListening = false; _errorMsg = e.toString(); });
    }
  }

  // ── PCM → dB ──────────────────────────────────────────────────────────────

  double _rmsToDb(List<int> bytes) {
    if (bytes.length < 2) return 0;
    double sumSq = 0;
    int n = 0;
    for (int i = 0; i + 1 < bytes.length; i += 2) {
      int s = bytes[i] | (bytes[i + 1] << 8);
      if (s > 32767) s -= 65536;
      sumSq += s * s;
      n++;
    }
    if (n == 0 || sumSq < 1) return 0;
    final rms = sqrt(sumSq / n);
    if (rms < 1) return 0;
    final dBFS = 20 * log(rms / 32768) / ln10;
    return ((dBFS + 90) / 90 * 120).clamp(0.0, 120.0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsedSec.dispose();
    _noDataTimer?.cancel();
    _pcmSub?.cancel();
    _recorder.stop().then((_) => _recorder.dispose());
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _dbColor(double db) {
    if (db < 40) return const Color(0xFF2E7D32);
    if (db < 60) return const Color(0xFF66BB6A);
    if (db < 80) return const Color(0xFF80CBC4); // teal-green
    if (db < 95) return Colors.yellow[600]!;
    return Colors.red[400]!;
  }

  String _dbLabel(double db) {
    if (!_isListening) return '…';
    final s = LanguageService.instance.strings;
    if (db < 20) return s.dbSilence;
    if (db < 40) return s.dbVeryQuiet;
    if (db < 60) return s.dbQuiet;
    if (db < 80) return s.dbModerate;
    if (db < 95) return s.dbLoud;
    return s.dbVeryLoud;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) return _buildNoPermission();
    if (_errorMsg == 'no_data' && !_isListening) return _buildNoData();
    final s = LanguageService.instance.strings;

    return Column(
      children: [
        const SizedBox(height: 8),

        // Starting spinner
        if (!_isListening && _errorMsg == null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: Color(0xFF66BB6A), strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(s.startingMic,
                    style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13)),
              ],
            ),
          ),

        // ── dB badge ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _dbColor(_smoothDb), width: 1.5),
            boxShadow: _isListening
                ? [BoxShadow(color: _dbColor(_smoothDb).withOpacity(0.25),
                    blurRadius: 12, spreadRadius: 2)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic, color: _dbColor(_smoothDb), size: 22),
              const SizedBox(width: 8),
              Text(
                _isListening ? '${_currentDb.toStringAsFixed(1)} dB' : '-- dB',
                style: TextStyle(
                  color: _dbColor(_smoothDb),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Text(_dbLabel(_currentDb),
                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
            ],
          ),
        ),

        // Retry error
        if (_errorMsg != null && _errorMsg != 'denied' &&
            _errorMsg != 'permanently_denied' && _errorMsg != 'no_data')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s.retrying(_errorMsg ?? ''),
                style: const TextStyle(color: Colors.orange, fontSize: 10),
                textAlign: TextAlign.center),
          ),

        const SizedBox(height: 16),

        // ── Flowing wave visualizer ──
        Expanded(
          child: AnimatedBuilder(
            animation: _elapsedSec,
            builder: (_, __) => CustomPaint(
              painter: _FlowingWavePainter(
                elapsedSec: _elapsedSec.value,
                amplitude: _isListening ? (_smoothDb / 120).clamp(0.05, 1.0) : 0.08,
                isListening: _isListening,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Thin level bar ──
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 4,
            color: const Color(0xFF1A2E1E),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (_smoothDb / 120).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF1B5E20),
                    const Color(0xFF66BB6A),
                    if (_smoothDb > 75) Colors.yellow[700]!,
                    if (_smoothDb > 95) Colors.red[400]!,
                  ]),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF66BB6A).withOpacity(0.4),
                        blurRadius: 6, spreadRadius: 1),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.dbQuiet, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
            Text(s.listeningToGarden,
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
            Text(s.dbLoud, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ── No-permission ─────────────────────────────────────────────────────────

  Widget _buildNoPermission() {
    final isPerm = _errorMsg == 'permanently_denied';
    final s = LanguageService.instance.strings;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off,
                color: isPerm ? Colors.red[400] : const Color(0xFF4CAF50), size: 56),
            const SizedBox(height: 16),
            Text(
              isPerm ? s.micPermBodyPerm : s.micPermBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: _requesting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(isPerm ? Icons.settings : Icons.mic),
              label: Text(isPerm ? s.openSettings : s.grantPermission),
              onPressed: _requesting ? null : () {
                if (isPerm) openAppSettings(); else _checkAndStart();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── No-data ───────────────────────────────────────────────────────────────

  Widget _buildNoData() {
    final s = LanguageService.instance.strings;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_none, color: Colors.orange, size: 56),
            const SizedBox(height: 16),
            Text(
              s.noAudioArrived,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(s.tryAgainBtn),
                  onPressed: () { setState(() => _errorMsg = null); _startListening(); },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF66BB6A),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: Text(s.settingsBtn),
                  onPressed: openAppSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flowing wave painter ──────────────────────────────────────────────────────
//
// Three layered sine waves:
//   Layer 1  — slow, wide, dark-green filled  (ocean swell)
//   Layer 2  — medium, medium-green filled    (surface wave)
//   Layer 3  — fast, thin teal stroke + glow  (foam / highlight)

class _FlowingWavePainter extends CustomPainter {
  // elapsedSec grows continuously from a Ticker — never resets, so sin()
  // never sees a phase jump.  Each layer has its own speed (rad/s).
  final double elapsedSec;
  final double amplitude;  // 0 … 1, derived from smoothDb
  final bool isListening;

  _FlowingWavePainter({
    required this.elapsedSec,
    required this.amplitude,
    required this.isListening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final mid = h * 0.5;

    // Each phaseOffset = elapsedSec * speed (rad/s).
    // sin() is 2π-periodic, so the wave flows smoothly forever.

    // ── Layer 1: slow deep swell (0.45 rad/s ≈ one cycle per 14 s) ───────
    _drawFilledWave(
      canvas, size,
      phaseOffset: elapsedSec * 0.45,
      cycles: 2.5,
      waveHeight: h * (0.12 + amplitude * 0.22),
      yCenter: mid + h * 0.04,
      topColors: [
        const Color(0xFF1B5E20).withOpacity(0.55),
        const Color(0xFF1B5E20).withOpacity(0.0),
      ],
    );

    // ── Layer 2: surface wave (0.72 rad/s ≈ one cycle per 8.7 s) ─────────
    _drawFilledWave(
      canvas, size,
      phaseOffset: elapsedSec * 0.72 + 1.0,
      cycles: 3.2,
      waveHeight: h * (0.08 + amplitude * 0.18),
      yCenter: mid,
      topColors: [
        const Color(0xFF2E7D32).withOpacity(0.65),
        const Color(0xFF2E7D32).withOpacity(0.0),
      ],
    );

    // ── Layer 3: foam/highlight line (1.05 rad/s ≈ one cycle per 6 s) ────
    _drawStrokeWave(
      canvas, size,
      phaseOffset: elapsedSec * 1.05 + 2.2,
      cycles: 4.0,
      waveHeight: h * (0.05 + amplitude * 0.13),
      yCenter: mid - h * 0.03,
      color: const Color(0xFF80CBC4),
      strokeWidth: 2.0,
      glowRadius: 8.0,
    );

    // ── Layer 4: faint slow reflection (0.28 rad/s ≈ one cycle per 22 s) ─
    _drawFilledWave(
      canvas, size,
      phaseOffset: elapsedSec * 0.28 + pi,
      cycles: 2.0,
      waveHeight: h * (0.06 + amplitude * 0.10),
      yCenter: mid + h * 0.15,
      topColors: [
        const Color(0xFF1B5E20).withOpacity(0.25),
        const Color(0xFF1B5E20).withOpacity(0.0),
      ],
    );
  }

  // ── Filled wave (colour fades to transparent toward the bottom) ───────────

  void _drawFilledWave(
    Canvas canvas,
    Size size, {
    required double phaseOffset,
    required double cycles,
    required double waveHeight,
    required double yCenter,
    required List<Color> topColors, // [opaque, transparent]
  }) {
    final path = _buildWavePath(size.width, size.height,
        phaseOffset: phaseOffset, cycles: cycles,
        waveHeight: waveHeight, yCenter: yCenter, fillToBottom: true);

    final rect = Rect.fromLTWH(0, yCenter - waveHeight, size.width,
        size.height - (yCenter - waveHeight));
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: topColors,
      stops: const [0.0, 1.0],
    ).createShader(rect);

    canvas.drawPath(path, Paint()..shader = shader..style = PaintingStyle.fill);
  }

  // ── Stroke wave with optional glow ────────────────────────────────────────

  void _drawStrokeWave(
    Canvas canvas,
    Size size, {
    required double phaseOffset,
    required double cycles,
    required double waveHeight,
    required double yCenter,
    required Color color,
    required double strokeWidth,
    double glowRadius = 0,
  }) {
    final path = _buildWavePath(size.width, size.height,
        phaseOffset: phaseOffset, cycles: cycles,
        waveHeight: waveHeight, yCenter: yCenter, fillToBottom: false);

    if (glowRadius > 0) {
      // Soft outer glow
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.3)
          ..strokeWidth = strokeWidth + glowRadius
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }

    // Crisp line on top
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.9)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── Shared path builder ───────────────────────────────────────────────────

  Path _buildWavePath(
    double w,
    double h, {
    required double phaseOffset,
    required double cycles,
    required double waveHeight,
    required double yCenter,
    required bool fillToBottom,
  }) {
    final path = Path();
    final step = w / 200; // 200 segments = smooth curve

    double y0 = yCenter + waveHeight * sin(phaseOffset);
    path.moveTo(0, y0);

    for (double x = step; x <= w + step; x += step) {
      final t = (x / w) * cycles * 2 * pi + phaseOffset;
      final y = yCenter + waveHeight * sin(t);
      path.lineTo(x.clamp(0, w), y);
    }

    if (fillToBottom) {
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
    }

    return path;
  }

  @override
  bool shouldRepaint(_FlowingWavePainter old) =>
      old.elapsedSec != elapsedSec ||
      old.amplitude != amplitude ||
      old.isListening != isListening;
}
