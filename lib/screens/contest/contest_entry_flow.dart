// lib/screens/contest/contest_entry_flow.dart
//
// Pick a plant → photograph it → place it on the five scales → submit.
//
// The plant can be anything the visitor is standing in front of: they search
// the garden's own index, or type a name if the plant is not in the records.
// A contest run while walking around cannot demand that every specimen already
// exists in a spreadsheet.
//
// Photo capture uses ResolutionPreset.medium deliberately — roughly 150 KB per
// shot against ~1 MB at high. Several hundred entries then cost a few pence of
// storage instead of a bill, and no image-compression dependency is needed.

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../data/plant_index.dart';
import '../../models/contest.dart';
import '../../services/auth_service.dart';
import '../../services/contest_service.dart';

class ContestEntryFlow extends StatefulWidget {
  const ContestEntryFlow({super.key, required this.contest});
  final Contest contest;

  @override
  State<ContestEntryFlow> createState() => _ContestEntryFlowState();
}

class _ContestEntryFlowState extends State<ContestEntryFlow> {
  final _searchCtrl = TextEditingController();

  String? _plantName;
  String _plantSection = '';
  File? _photo;
  final Map<String, int> _ratings = {};
  bool _saving = false;
  String? _error;

  ContestTeam? _team;

  @override
  void initState() {
    super.initState();
    for (final a in widget.contest.axes) {
      _ratings[a.key] = 0; // dead centre — no pre-selected opinion
    }
    PlantIndex.instance.ready().then((_) => mounted ? setState(() {}) : null);
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    final uid = AuthService.instance.currentUser?.id;
    if (uid == null) return;
    final t = await ContestService.instance.myTeam(widget.contest.id, uid);
    if (mounted) setState(() => _team = t);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PlantFacts> _suggestions() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.length < 2) return const [];
    final out = <PlantFacts>[];
    for (final p in PlantIndex.instance.all) {
      final hay = [
        p.scientificName,
        p.englishName ?? '',
        p.finnishName ?? '',
      ].join(' ').toLowerCase();
      if (hay.contains(q)) out.add(p);
      if (out.length >= 12) break;
    }
    return out;
  }

  Future<void> _takePhoto() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;
      final file = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(builder: (_) => _ContestCamera(camera: cameras.first)),
      );
      if (file != null && mounted) setState(() => _photo = File(file.path));
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera unavailable: $e');
    }
  }

  Future<void> _submit() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to take part.');
      return;
    }
    final name = _plantName?.trim();
    if (name == null || name.isEmpty) {
      setState(() => _error = 'Choose a plant first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final key = ContestEntry.keyFor(name);
    final entry = ContestEntry(
      id: ContestEntry.docId(widget.contest.id, user.id, key),
      contestId: widget.contest.id,
      uid: user.id,
      displayName: user.displayName.isEmpty ? 'Visitor' : user.displayName,
      plantKey: key,
      plantName: name,
      plantSection: _plantSection,
      ratings: Map.of(_ratings),
      createdAt: DateTime.now(),
      teamId: _team?.id,
      teamName: _team?.name,
    );

    try {
      await ContestService.instance.submitEntry(entry, photo: _photo);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B4020),
          content: Text('$name added to the leaderboard.',
              style: const TextStyle(color: Color(0xFFE8F5E9))),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('Add a plant'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_team != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Playing for team ${_team!.name}',
                  style: const TextStyle(
                      color: Color(0xFFFFB74D), fontSize: 12.5)),
            ),

          _label('1  ·  WHICH PLANT?'),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            onChanged: (v) => setState(() => _plantName = v.trim().isEmpty ? null : v.trim()),
            decoration: InputDecoration(
              hintText: 'Search, or just type what you see',
              hintStyle: const TextStyle(color: Color(0xFF6E8A72)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF81C784)),
              filled: true,
              fillColor: const Color(0xFF13301A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111F16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A4A2F)),
              ),
              child: Column(
                children: [
                  for (final p in suggestions)
                    ListTile(
                      dense: true,
                      title: Text(p.scientificName,
                          style: const TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 13.5,
                              fontStyle: FontStyle.italic)),
                      subtitle: Text(
                        [
                          p.englishName ?? p.finnishName ?? '',
                          PlantIndex.instance.sectionLabel(p.sectionCode),
                        ].where((e) => e.isNotEmpty).join('  ·  '),
                        style: const TextStyle(
                            color: Color(0xFF6E8A72), fontSize: 11.5),
                      ),
                      onTap: () {
                        setState(() {
                          _plantName = p.scientificName;
                          _plantSection =
                              PlantIndex.instance.sectionLabel(p.sectionCode);
                          _searchCtrl.text = p.scientificName;
                        });
                        FocusScope.of(context).unfocus();
                      },
                    ),
                ],
              ),
            ),
          if (_plantName != null && suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Using "$_plantName" — not in the garden records, that is fine.',
                style: const TextStyle(color: Color(0xFF6E8A72), fontSize: 12),
              ),
            ),

          const SizedBox(height: 22),
          _label('2  ·  PHOTO'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: _photo == null ? 96 : 200,
              decoration: BoxDecoration(
                color: const Color(0xFF13301A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E7D32)),
                image: _photo == null
                    ? null
                    : DecorationImage(
                        image: FileImage(_photo!), fit: BoxFit.cover),
              ),
              child: _photo != null
                  ? null
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_rounded,
                              color: Color(0xFF81C784)),
                          SizedBox(height: 6),
                          Text('Tap to photograph it',
                              style: TextStyle(
                                  color: Color(0xFF81C784), fontSize: 13)),
                          Text('Only you will see this photo',
                              style: TextStyle(
                                  color: Color(0xFF4A7A50), fontSize: 11)),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 22),
          _label('3  ·  WHAT KIND OF VIBE?'),
          const SizedBox(height: 4),
          const Text('There are no right answers. Trust your first impression.',
              style: TextStyle(color: Color(0xFF6E8A72), fontSize: 12)),
          const SizedBox(height: 12),
          for (final a in widget.contest.axes) _axisSlider(a),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 13)),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving…' : 'Submit my pick'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF231A00),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _axisSlider(ContestAxis a) {
    final v = (_ratings[a.key] ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.left,
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Text(a.right,
                  style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFFFB300),
              inactiveTrackColor: const Color(0xFF13301A),
              thumbColor: const Color(0xFFFFD54F),
              overlayColor: const Color(0x33FFD54F),
            ),
            child: Slider(
              value: v,
              min: -5,
              max: 5,
              divisions: 10,
              onChanged: (nv) =>
                  setState(() => _ratings[a.key] = nv.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Color(0xFF81C784),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2));
}

/// Minimal capture screen. Medium resolution keeps the upload small enough that
/// a whole event's photos cost almost nothing to store.
class _ContestCamera extends StatefulWidget {
  const _ContestCamera({required this.camera});
  final CameraDescription camera;

  @override
  State<_ContestCamera> createState() => _ContestCameraState();
}

class _ContestCameraState extends State<_ContestCamera> {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller!.initialize().then((_) => mounted ? setState(() {}) : null);
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
      body: c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Center(child: CameraPreview(c)),
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
                        border: Border.all(
                            color: const Color(0xFFFFB300), width: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
