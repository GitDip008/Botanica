import 'dart:io';
import 'package:camera/camera.dart';
import '../services/camera_utils.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/chat_service.dart';
import '../services/gemini_service.dart';
import '../services/language_service.dart';
import '../services/plant_identification_service.dart';
import '../services/usage_tracking_service.dart';
import 'plant_result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isLoading = false;
  bool _isInitialized = false;
  final _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  List<CameraDescription> _cameras = const [];
  CameraDescription? _active;

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    // Rear-facing by default — availableCameras().first is the FRONT camera on
    // many devices, which pointed the app at the visitor instead of the plant.
    await _open(preferredCamera(_cameras));
  }

  Future<void> _open(CameraDescription cam) async {
    await _controller?.dispose();
    if (mounted) setState(() => _isInitialized = false);
    _active = cam;
    _controller = CameraController(cam, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _switchCamera() async {
    final cur = _active;
    if (cur == null) return;
    final next = nextCamera(_cameras, cur);
    if (next != null) await _open(next);
  }

  Future<void> _captureAndIdentify() async {
    if (_controller == null || !_controller!.value.isInitialized || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final file = await _controller!.takePicture();
      final bytes = await File(file.path).readAsBytes();
      UsageTrackingService.instance
          .log(UsageTrackingService.featurePlantId);

      // 🌿 Free identification: PlantNet → Cloud LLM description.
      // Falls back to Gemini automatically if PlantNet fails OR returns
      // a low-confidence guess.
      final plantInfo =
          await PlantIdentificationService.instance.identify(bytes);

      if (!mounted) return;

      // ── No plant detected — show a clear message, stay on camera ─────
      if (!plantInfo.isPlant) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B0B14),
            duration: const Duration(seconds: 4),
            content: Row(
              children: const [
                Icon(Icons.error_outline_rounded,
                    color: Color(0xFFFFCDD2), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Couldn't detect a plant. Get closer to a leaf or flower and try again.",
                    style: TextStyle(color: Color(0xFFFFCDD2)),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      // Seed chat context across all engines (cloud / local / Gemini fallback).
      await ChatService.instance.seedPlantContext(plantInfo);

      if (!mounted) return;
      setState(() => _isLoading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantResultScreen(
            imagePath: file.path,
            plantInfo: plantInfo,
            geminiService: _geminiService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[900],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && _controller != null)
            CameraPreview(_controller!)
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF66BB6A)),
            ),

          // Camera switch — only shown when the device actually has another
          // one, so the control never appears as a button that does nothing.
          if (_isInitialized && hasMultipleCameras(_cameras))
            Positioned(
              right: 16,
              bottom: 130,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Switch camera',
                  icon: Icon(
                    Icons.flip_camera_android_rounded,
                    color: _active != null && isFront(_active!)
                        ? const Color(0xFFFFD54F)
                        : Colors.white,
                  ),
                  onPressed: _switchCamera,
                ),
              ),
            ),

          // Top title bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '📸 Botanica',
                    style: TextStyle(
                      color: Color(0xFF66BB6A),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LanguageService.instance.strings.identifyTagline,
                    style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Bottom capture bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 52),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLoading ? 'Identifying plant...' : 'Point at a plant and capture',
                    style: const TextStyle(
                      color: Color(0xFFE8F5E9),
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _captureAndIdentify,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF66BB6A),
                          width: 3,
                        ),
                        color: _isLoading
                            ? const Color(0xFF2E7D32).withOpacity(0.4)
                            : Colors.white.withOpacity(0.12),
                      ),
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF66BB6A),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.eco_rounded,
                              color: Color(0xFF66BB6A),
                              size: 38,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
