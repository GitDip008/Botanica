// lib/screens/gallery/gallery_compose.dart
//
// Capture a photo, write a caption, choose who sees it.
//
// Defaults to private. That is the safer default at a public garden, and it
// also means the common case never touches the network: the image is copied
// into the app's directory and nothing is uploaded unless the visitor asks for
// it to be shared.

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../data/plant_index.dart';
import '../../services/camera_utils.dart';
import '../../models/gallery_post.dart';
import '../../services/auth_service.dart';
import '../../services/gallery_service.dart';

class GalleryCompose extends StatefulWidget {
  const GalleryCompose({super.key});

  @override
  State<GalleryCompose> createState() => _GalleryComposeState();
}

class _GalleryComposeState extends State<GalleryCompose> {
  final _captionCtrl = TextEditingController();
  final _plantCtrl = TextEditingController();

  Uint8List? _photo;
  bool _makePublic = false;
  bool _saving = false;
  String? _error;

  /// Set once the photo is safely in the diary. A retry after a failed share
  /// then reuses that post rather than saving a second copy.
  GalleryPost? _saved;

  @override
  void initState() {
    super.initState();
    PlantIndex.instance.ready().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _plantCtrl.dispose();
    super.dispose();
  }

  List<PlantFacts> _plantSuggestions() {
    final q = _plantCtrl.text.trim().toLowerCase();
    if (q.length < 2) return const [];
    final out = <PlantFacts>[];
    for (final p in PlantIndex.instance.all) {
      final hay = [
        p.scientificName,
        p.englishName ?? '',
        p.finnishName ?? '',
      ].join(' ').toLowerCase();
      if (hay.contains(q)) out.add(p);
      if (out.length >= 8) break;
    }
    return out;
  }

  Future<void> _capture() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty || !mounted) return;
      final shot = await Navigator.push<XFile?>(
        context,
        MaterialPageRoute(
          builder: (_) => _GalleryCamera(
            camera: preferredCamera(cams),
            all: cams,
          ),
        ),
      );
      if (shot != null && mounted) {
        // Bytes, not File: on web the XFile path is a blob URL and
        // File() throws UnsupportedOperation: _Namespace.
        final bytes = await shot.readAsBytes();
        if (mounted) setState(() => _photo = bytes);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera unavailable: $e');
    }
  }

  Future<void> _save() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Sign in to save photos.');
      return;
    }
    if (_photo == null) {
      setState(() => _error = 'Take a photo first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    // Which step is running, so a failure says what actually went wrong rather
    // than one "could not save" covering three quite different causes.
    var step = 'save the photo';
    try {
      if (_saved == null) {
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        // Copy out of the camera's temp directory before anything else — that
        // cache is fair game for the OS to clear.
        final localPath = await GalleryService.instance
            .persistPhoto(_photo!, id, uid: user.id);

        final post = GalleryPost(
          id: id,
          uid: user.id,
          displayName: user.displayName.isEmpty ? 'Visitor' : user.displayName,
          caption: _captionCtrl.text.trim(),
          plantName:
              _plantCtrl.text.trim().isEmpty ? null : _plantCtrl.text.trim(),
          visibility: PostVisibility.private,
          createdAt: DateTime.now(),
          localPath: localPath,
        );
        await GalleryService.instance.upsertLocal(post);
        _saved = post;
      }

      if (_makePublic) {
        step = 'share it';
        // Hand over the bytes we are still holding: sharing a photo just taken
        // then needs one upload, not an upload followed by a download and
        // another upload.
        await GalleryService.instance.publish(_saved!, bytes: _photo);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _saved == null
              ? 'Could not $step: $e'
              : 'Saved to your diary, but could not $step: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _plantSuggestions();

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1F14),
        elevation: 0,
        title: const Text('New photo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          GestureDetector(
            onTap: _capture,
            child: Container(
              height: _photo == null ? 150 : 260,
              decoration: BoxDecoration(
                color: const Color(0xFF13301A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32)),
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
                          Icon(Icons.add_a_photo_rounded,
                              color: Color(0xFF81C784), size: 30),
                          SizedBox(height: 8),
                          Text('Tap to take a photo',
                              style: TextStyle(
                                  color: Color(0xFF81C784), fontSize: 14)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          TextField(
            controller: _captionCtrl,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            decoration: InputDecoration(
              hintText: 'Say something about it…',
              hintStyle: const TextStyle(color: Color(0xFF6E8A72)),
              counterStyle: const TextStyle(color: Color(0xFF4A7A50)),
              filled: true,
              fillColor: const Color(0xFF13301A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          TextField(
            controller: _plantCtrl,
            style: const TextStyle(color: Color(0xFFE8F5E9)),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Which plant? (optional)',
              hintStyle: const TextStyle(color: Color(0xFF6E8A72)),
              prefixIcon:
                  const Icon(Icons.local_florist_outlined, color: Color(0xFF81C784)),
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
                      onTap: () {
                        setState(() => _plantCtrl.text = p.scientificName);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                ],
              ),
            ),

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111F16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2A4A2F)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _makePublic,
                  activeThumbColor: const Color(0xFF81C784),
                  onChanged: (v) => setState(() => _makePublic = v),
                  title: Text(
                    _makePublic ? 'Share with everyone' : 'Only you',
                    style: const TextStyle(
                        color: Color(0xFFE8F5E9),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _makePublic
                        ? 'Anyone using the app will see this photo and can react to it.'
                        : 'Stays on this phone. Nothing is uploaded — you can share it later.',
                    style: const TextStyle(
                        color: Color(0xFF9CCC9F), fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 13)),
          ],

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving…' : 'Save'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Medium resolution: ~150 KB a shot. Small enough that a shared photo costs
/// almost nothing to serve, and large enough to look right on a phone.
class _GalleryCamera extends StatefulWidget {
  const _GalleryCamera({required this.camera, required this.all});
  final CameraDescription camera;
  final List<CameraDescription> all;

  @override
  State<_GalleryCamera> createState() => _GalleryCameraState();
}

class _GalleryCameraState extends State<_GalleryCamera> {
  CameraController? _controller;
  late CameraDescription _active = widget.camera;

  Future<void> _switch() async {
    final next = nextCamera(widget.all, _active);
    if (next == null) return;
    await _controller?.dispose();
    if (mounted) setState(() => _controller = null);
    _active = next;
    final c = CameraController(next, ResolutionPreset.medium, enableAudio: false);
    await c.initialize();
    if (mounted) setState(() => _controller = c);
  }

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium,
        enableAudio: false);
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
                        border: Border.all(
                            color: const Color(0xFF81C784), width: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
