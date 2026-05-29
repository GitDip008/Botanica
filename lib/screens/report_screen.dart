import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../services/report_service.dart';

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
      : 'No GPS';

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
  static const _apiKey = ApiConfig.geminiApiKey;
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
      final bytes = await File(file.path).readAsBytes();
      setState(() {
        _imagePath = file.path;
        _capturing = false;
        _analyzing = true;
      });

      final model =
          GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      const prompt = '''You are helping document a finding at Oulu Botanical Garden.
Describe what you see in this image in 2-3 sentences. Focus on:
- Any visible damage, disease, pests, or unusual features
- The plant or plants visible
- Any concern level (none / minor / significant)
Be concise and factual.''';
      final response = await model.generateContent([
        Content.multi([DataPart('image/jpeg', bytes), TextPart(prompt)]),
      ]);
      if (mounted) {
        setState(() {
          _aiDescription =
              response.text ?? 'Unable to analyse image.';
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _analyzing = false;
          _aiDescription = 'Analysis failed: $e';
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
        : 'GPS not available';

    final body = '''
Report submitted via Botanica AR visitor app
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Date & time : ${r.timeText}
Category    : ${r.category}
GPS         : ${r.gpsText}
Map link    : $gpsLink

AI Analysis (Gemini):
${r.aiDescription}

Visitor note:
${r.note.isEmpty ? '(none)' : r.note}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sent from Botanica AR — Oulu Botanical Garden companion app.
''';

    final uri = Uri(
      scheme: 'mailto',
      path: _authorityEmail,
      queryParameters: {
        'subject': '[Botanica AR] ${r.category} — ${r.timeText}',
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email app found on this device.'),
            backgroundColor: Colors.orange,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF66BB6A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🔬 Report a Find',
            style: TextStyle(
                color: Color(0xFFE8F5E9),
                fontWeight: FontWeight.bold)),
        actions: [
          if (_reports.isNotEmpty)
            TextButton(
              onPressed: _showHistory,
              child: Text(
                '${_reports.length} saved',
                style: const TextStyle(
                    color: Color(0xFF66BB6A), fontSize: 12),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo thumbnail
          if (File(r.imagePath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(r.imagePath),
                  height: 180, fit: BoxFit.cover),
            ),

          const SizedBox(height: 20),

          const Center(
            child: Text('✅',
                style: TextStyle(fontSize: 52)),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text('Report Saved!',
                style: TextStyle(
                    color: Color(0xFF66BB6A),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${r.category}  ·  ${r.timeText}\n📍 ${r.gpsText}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 13,
                  height: 1.6),
            ),
          ),

          const SizedBox(height: 20),

          // Where is it saved box
          Container(
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
                  Icon(Icons.storage,
                      color: Color(0xFF66BB6A), size: 16),
                  SizedBox(width: 6),
                  Text('Where is this stored?',
                      style: TextStyle(
                          color: Color(0xFF66BB6A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                const Text(
                  '• Saved on this phone — survives app restarts\n'
                  '• Tap "View All Reports" to see the full history\n'
                  '• Tap "Email Garden Staff" to notify the authority\n'
                  '• Your photo and GPS location are included',
                  style: TextStyle(
                      color: Color(0xFFE8F5E9),
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
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Email Garden Staff  📧',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: () => _emailAuthority(r),
          ),

          const SizedBox(height: 8),

          const Text(
            'Opens your email app pre-filled with the full report.\n'
            'One tap to send — garden staff are notified instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF4CAF50), fontSize: 11, height: 1.5),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF66BB6A),
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('View All Reports',
                      style: TextStyle(fontSize: 13)),
                  onPressed: _showHistory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('New Report',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera / preview
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2E7D32)),
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
                                        color: const Color(0xFF66BB6A),
                                        width: 2.5),
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  child: _capturing
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              color: Color(0xFF66BB6A),
                                              strokeWidth: 2))
                                      : const Icon(Icons.camera_alt,
                                          color: Color(0xFF66BB6A), size: 28),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF66BB6A))),
          ),

          const SizedBox(height: 14),

          // AI analysis
          if (_analyzing)
            const Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Color(0xFF66BB6A), strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Gemini analysing image…',
                    style: TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 13)),
              ],
            ),
          if (_aiDescription.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_awesome,
                        color: Color(0xFF66BB6A), size: 14),
                    SizedBox(width: 6),
                    Text('AI Analysis',
                        style: TextStyle(
                            color: Color(0xFF66BB6A),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_aiDescription,
                      style: const TextStyle(
                          color: Color(0xFFE8F5E9),
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Category
          const Text('Category',
              style: TextStyle(
                  color: Color(0xFF66BB6A),
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
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF1A2E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF2E7D32)),
                  ),
                  child: Text(cat,
                      style: TextStyle(
                          color: sel
                              ? Colors.white
                              : const Color(0xFF66BB6A),
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
              color: const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E7D32)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on,
                    color: _location != null
                        ? const Color(0xFF66BB6A)
                        : Colors.orange,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _location != null
                        ? 'GPS: ${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}'
                        : 'Getting location…',
                    style: TextStyle(
                      color: _location != null
                          ? const Color(0xFF66BB6A)
                          : Colors.orange,
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
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add your note (optional)…',
              filled: true,
              fillColor: const Color(0xFF1A2E1E),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2E7D32))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2E7D32))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF66BB6A), width: 2)),
              hintStyle:
                  const TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _imagePath != null
                  ? const Color(0xFF2E7D32)
                  : Colors.grey[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.send),
            label: const Text('Submit Report',
                style: TextStyle(fontSize: 15)),
            onPressed: _imagePath != null ? _submitReport : null,
          ),

          const SizedBox(height: 8),
          const Text(
            'Report is saved on this device and you can email it\n'
            'directly to garden staff after submission.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF4CAF50), fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── History bottom sheet ──────────────────────────────────────────────────

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2E1E),
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
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text('Saved Reports',
                      style: TextStyle(
                          color: Color(0xFF66BB6A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  Text('${_reports.length} total',
                      style: const TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 12)),
                ],
              ),
            ),
            if (_reports.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No reports yet.',
                      style: TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 14)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _reports.length,
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1F14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF2E7D32)),
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
                                        const Color(0xFF1A2E1E),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                      Icons.image_not_supported,
                                      color: Color(0xFF4CAF50)),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.category,
                                        style: const TextStyle(
                                            color: Color(0xFFE8F5E9),
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 13)),
                                    Text(r.timeText,
                                        style: const TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 11)),
                                    Text('📍 ${r.gpsText}',
                                        style: const TextStyle(
                                            color: Color(0xFF4CAF50),
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
                                    color: Color(0xFFE8F5E9),
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
                              label: const Text(
                                  'Email Garden Staff',
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
