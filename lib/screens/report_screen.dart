import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/gemini_proxy.dart';
import '../services/language_service.dart';
import '../services/report_service.dart';
import '../services/usage_tracking_service.dart';
import '../theme/tokens.dart';
import '../i18n/tr.dart';

// ─── Authority contact ────────────────────────────────────────────────────────
// Change this to the real garden staff email before deployment.
const _authorityEmail = 'kasvitieteellinen.puutarha@oulu.fi';

// ─── Data model ───────────────────────────────────────────────────────────────

class _Report {
  final String imagePath;
  final String category;
  final String aiDescription;
  final String note;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  _Report({
    required this.imagePath,
    required this.category,
    required this.aiDescription,
    required this.note,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'category': category,
        'aiDescription': aiDescription,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _Report.fromJson(Map<String, dynamic> j) => _Report(
        imagePath: j['imagePath'] as String,
        category: j['category'] as String,
        aiDescription: j['aiDescription'] as String,
        note: j['note'] as String,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        timestamp: DateTime.parse(j['timestamp'] as String),
      );

  String get gpsText => latitude != null
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : tr('No GPS');

  String get timeText {
    final t = timestamp;
    return '${t.day}/${t.month}/${t.year}  '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _prefsKey = 'botanical_reports';
  static const _categories = [
    'Pest damage',
    'Rare species',
    'Unusual growth',
    'Disease',
    'Other',
  ];

  // Camera
  CameraController? _cam;
  bool _camReady = false;
  bool _capturing = false;

  // Form state
  String? _imagePath;
  String _aiDescription = '';
  bool _analyzing = false;
  Position? _location;
  String _selectedCategory = 'Pest damage';
  final _noteCtrl = TextEditingController();

  // Reports
  List<_Report> _reports = [];
  _Report? _lastSubmitted; // used on success screen

  @override
  void initState() {
    super.initState();
    _loadReports();
    _initCamera();
    _getLocation();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    final loaded = raw.map((s) {
      try {
        return _Report.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<_Report>().toList();
    if (mounted) setState(() => _reports = loaded);
  }

  Future<void> _saveReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefsKey, _reports.map((r) => jsonEncode(r.toJson())).toList());
  }

  // ── Camera + location ─────────────────────────────────────────────────────

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

  Future<void> _getLocation() async {
    final s = await Permission.location.request();
    if (!s.isGranted) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _location = pos);
    } catch (_) {}
  }

  // ── Capture + AI analysis ─────────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (_cam == null || !_cam!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _cam!.takePicture();
      final bytes = await file.readAsBytes();
      setState(() {
        _imagePath = file.path;
        _capturing = false;
        _analyzing = true;
      });

      const prompt = '''You are helping document a finding at Oulu Botanical Garden.
Describe what you see in this image in 2-3 sentences. Focus on:
- Any visible damage, disease, pests, or unusual features
- The plant or plants visible
- Any concern level (none / minor / significant)
Be concise and factual.''';
      final text = await GeminiProxy.instance.vision(
        prompt: prompt,
        imageBytes: bytes,
        model: 'gemini-2.5-flash',
      );
      if (mounted) {
        setState(() {
          _aiDescription = text.isNotEmpty ? text : tr('Unable to analyse image.');
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _analyzing = false;
          _aiDescription = tr('Analysis failed: {0}', [e]);
        });
      }
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submitReport() async {
    if (_imagePath == null) return;
    final report = _Report(
      imagePath: _imagePath!,
      category: _selectedCategory,
      aiDescription: _aiDescription,
      note: _noteCtrl.text.trim(),
      latitude: _location?.latitude,
      longitude: _location?.longitude,
      timestamp: DateTime.now(),
    );
    setState(() {
      _reports.insert(0, report); // newest first
      _lastSubmitted = report;
    });
    await _saveReports(); // persist to disk
    UsageTrackingService.instance.log(UsageTrackingService.featureReport);
    // Also mirror to Firestore so admins can see it
    await ReportService.instance.save(
      category: report.category,
      aiDescription: report.aiDescription,
      note: report.note,
      latitude: report.latitude,
      longitude: report.longitude,
      timestamp: report.timestamp,
    );
  }

  void _resetForm() {
    setState(() {
      _imagePath = null;
      _aiDescription = '';
      _noteCtrl.clear();
      _lastSubmitted = null;
    });
  }

  // ── Email authority ───────────────────────────────────────────────────────

  Future<void> _emailAuthority(_Report r) async {
    final gpsLink = r.latitude != null
        ? 'https://maps.google.com/?q=${r.latitude},${r.longitude}'
        : tr('GPS not available');

    final body = tr('\nReport submitted via Botanica AR visitor app\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nDate & time : {0}\nCategory    : {1}\nGPS         : {2}\nMap link    : {3}\n\nAI Analysis (Gemini):\n{4}\n\nVisitor note:\n{5}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\nSent from Botanica AR — Oulu Botanical Garden companion app.\n', [r.timeText, r.category, r.gpsText, gpsLink, r.aiDescription, r.note.isEmpty ? '(none)' : r.note]);

    final uri = Uri(
      scheme: 'mailto',
      path: _authorityEmail,
      queryParameters: {
        'subject': tr('[Botanica AR] {0} — {1}', [r.category, r.timeText]),
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(LanguageService.instance.strings.noEmailAppFound),
            backgroundColor: C.gold,
          ),
        );
      }
    }
  }

  // ── Delete report ─────────────────────────────────────────────────────────

  Future<void> _deleteReport(int index) async {
    setState(() => _reports.removeAt(index));
    await _saveReports();
  }

  @override
  void dispose() {
    _cam?.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = LanguageService.instance.strings;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: C.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.reportTitle,
            style: const TextStyle(
                color: C.textHi,
                fontWeight: FontWeight.bold)),
        actions: [
          if (_reports.isNotEmpty)
            TextButton(
              onPressed: _showHistory,
              child: Text(
                tr('{0} saved', [_reports.length]),
                style: const TextStyle(
                    color: C.accent, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _lastSubmitted != null
          ? _buildSuccess(_lastSubmitted!)
          : _buildForm(),
    );
  }

  // ── Success screen ────────────────────────────────────────────────────────

  Widget _buildSuccess(_Report r) {
    final s = LanguageService.instance.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo thumbnail
          if (File(r.imagePath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(File(r.imagePath),
                  height: 180, fit: BoxFit.cover),
            ),

          const SizedBox(height: 20),

          const Center(
            child: Text('✅',
                style: TextStyle(fontSize: 52)),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(s.reportSaved,
                style: const TextStyle(
                    color: C.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${r.category}  ·  ${r.timeText}\n📍 ${r.gpsText}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: C.accent,
                  fontSize: 13,
                  height: 1.6),
            ),
          ),

          const SizedBox(height: 20),

          // Where is it saved box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.storage,
                      color: C.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(s.whereIsThisStored,
                      style: const TextStyle(
                          color: C.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                Text(
                  tr('• Saved on this phone — survives app restarts\n• Tap "View All Reports" to see the full history\n• Tap "Email Garden Staff" to notify the authority\n• Your photo and GPS location are included'),
                  style: TextStyle(
                      color: C.textHi,
                      fontSize: 13,
                      height: 1.6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Email authority — primary action
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.email_outlined),
            label: Text(s.emailGardenStaff,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: () => _emailAuthority(r),
          ),

          const SizedBox(height: 8),

          Text(
            tr('Opens your email app pre-filled with the full report.\nOne tap to send — garden staff are notified instantly.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: C.accent, fontSize: 11, height: 1.5),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.accent,
                    side: const BorderSide(color: C.accentDim),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(s.viewAllReports,
                      style: TextStyle(fontSize: 13)),
                  onPressed: _showHistory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: C.accentDim,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: Text(s.newReport,
                      style: TextStyle(fontSize: 13)),
                  onPressed: _resetForm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    final s = LanguageService.instance.strings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera / preview
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.hardEdge,
            child: _imagePath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_imagePath!), fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _imagePath = null;
                            _aiDescription = '';
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  )
                : _camReady && _cam != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_cam!),
                          Positioned(
                            bottom: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _captureAndAnalyze,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: C.accent,
                                        width: 2.5),
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  child: _capturing
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              color: C.accent,
                                              strokeWidth: 2))
                                      : const Icon(Icons.camera_alt,
                                          color: C.accent, size: 28),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            color: C.accent)),
          ),

          const SizedBox(height: 14),

          // AI analysis
          if (_analyzing)
            Row(
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: C.accent, strokeWidth: 2)),
                const SizedBox(width: 10),
                Text(LanguageService.instance.strings.analyzingImage,
                    style: const TextStyle(
                        color: C.accent, fontSize: 13)),
              ],
            ),
          if (_aiDescription.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome,
                        color: C.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(s.aiAnalysisLabel,
                        style: const TextStyle(
                            color: C.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_aiDescription,
                      style: const TextStyle(
                          color: C.textHi,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Category
          Text(s.categoryLabel,
              style: const TextStyle(
                  color: C.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final sel = cat == _selectedCategory;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? C.accentDim
                        : C.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tr(cat),
                      style: TextStyle(
                          color: sel
                              ? Colors.white
                              : C.accent,
                          fontSize: 12)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // GPS tag
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    color: _location != null
                        ? C.accent
                        : C.gold,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _location != null
                        ? '${s.gpsLabel}: ${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}'
                        : s.gettingLocation,
                    style: TextStyle(
                      color: _location != null
                          ? C.accent
                          : C.gold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Note
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: C.textHi),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: s.addNoteHint,
              filled: true,
              fillColor: C.surface,
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _imagePath != null
                  ? C.accentDim
                  : Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            icon: const Icon(Icons.send),
            label: Text(s.submitReport,
                style: TextStyle(fontSize: 15)),
            onPressed: _imagePath != null ? _submitReport : null,
          ),

          const SizedBox(height: 8),
          Text(
            tr('Report is saved on this device and you can email it\ndirectly to garden staff after submission.'),
            textAlign: TextAlign.center,
            style: TextStyle(
                color: C.accent, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── History bottom sheet ──────────────────────────────────────────────────

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: C.accentDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(LanguageService.instance.strings.savedReports,
                      style: TextStyle(
                          color: C.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  Text(tr('{0} total', [_reports.length]),
                      style: const TextStyle(
                          color: C.accent, fontSize: 12)),
                ],
              ),
            ),
            if (_reports.isEmpty)
              Expanded(
                child: Center(
                  child: Text(LanguageService.instance.strings.noReportsYet,
                      style: const TextStyle(
                          color: C.accent, fontSize: 14)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: _reports.length,
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (File(r.imagePath).existsSync())
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  child: Image.file(
                                    File(r.imagePath),
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color:
                                        C.surface,
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                      Icons.image_not_supported,
                                      color: C.accent),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.category,
                                        style: const TextStyle(
                                            color: C.textHi,
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 13)),
                                    Text(r.timeText,
                                        style: const TextStyle(
                                            color: C.accent,
                                            fontSize: 11)),
                                    Text('📍 ${r.gpsText}',
                                        style: const TextStyle(
                                            color: C.accent,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              // Delete
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 18),
                                onPressed: () async {
                                  await _deleteReport(i);
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showHistory();
                                  }
                                },
                              ),
                            ],
                          ),
                          if (r.aiDescription.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(r.aiDescription,
                                style: const TextStyle(
                                    color: C.textHi,
                                    fontSize: 12,
                                    height: 1.4),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 8),
                          // Email button per report
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    const Color(0xFF64B5F6),
                                side: const BorderSide(
                                    color: Color(0xFF1565C0)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.email_outlined,
                                  size: 14),
                              label: Text(
                                  tr('Email Garden Staff'),
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () => _emailAuthority(r),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
