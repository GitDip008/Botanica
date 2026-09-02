// lib/widgets/zoomable_camera_preview.dart
//
// CameraPreview with pinch-to-zoom and a tap stepper.
//
// Two things here are deliberate and both were bugs first:
//
//   • The widget tree above the preview NEVER changes shape. On web the preview
//     is a platform view — a real <video> element — and re-parenting it stops
//     the stream, leaving a frozen first frame. Discovering the zoom range is
//     asynchronous, so a build that switched from "bare preview" to "preview
//     inside a Stack" once the range arrived froze every web camera.
//   • The zoom controls only appear once the camera reports a usable range.
//     camera_web drives zoom through MediaStreamTrack constraints and throws
//     when the browser does not support them, so on some browsers there is
//     genuinely nothing to show.
//
// ponytail: no zoom animation, no ratio presets (0.5×/2×/3×) — devices report
// wildly different ranges and a preset that does not exist is worse than none.

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera_utils.dart';

class ZoomableCameraPreview extends StatefulWidget {
  const ZoomableCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  State<ZoomableCameraPreview> createState() => _ZoomableCameraPreviewState();
}

class _ZoomableCameraPreviewState extends State<ZoomableCameraPreview> {
  double _min = 1, _max = 1, _zoom = 1, _base = 1;

  @override
  void initState() {
    super.initState();
    _readRange();
  }

  @override
  void didUpdateWidget(ZoomableCameraPreview old) {
    super.didUpdateWidget(old);
    // A camera switch hands us a different controller with its own range.
    if (old.controller != widget.controller) {
      _zoom = 1;
      _readRange();
    }
  }

  Future<void> _readRange() async {
    try {
      final min = await widget.controller.getMinZoomLevel();
      final max = await widget.controller.getMaxZoomLevel();
      if (mounted) setState(() { _min = min; _max = max; });
    } catch (_) {
      // Platform does not report zoom — controls stay hidden.
    }
  }

  bool get _canZoom => _max > _min + 0.01;

  void _step(int direction) =>
      _apply(nextZoom(_zoom, direction, _min, _max));

  Future<void> _apply(double v) async {
    final z = v.clamp(_min, _max);
    if (mounted) setState(() => _zoom = z);
    try {
      await widget.controller.setZoomLevel(z);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Fixed shape whatever the zoom range turns out to be — the controls
    // appear by swapping a leaf, never by wrapping the preview in a new
    // parent. That is what keeps the web <video> element attached.
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onScaleStart: (_) => _base = _zoom,
          onScaleUpdate: (d) {
            if (_canZoom && d.pointerCount > 1) _apply(_base * d.scale);
          },
          onDoubleTap: _canZoom ? () => _apply(_zoom > _min ? _min : 2) : null,
          child: CameraPreview(widget.controller),
        ),
        // Left edge, vertically centred. Every screen that hosts this widget
        // lays its own controls over the bottom of the preview — the identify
        // screen's capture bar covered the whole lower strip, which is why
        // these buttons did nothing there. The middle of the left edge is the
        // one place no host paints.
        Positioned(
          left: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: !_canZoom
                ? const SizedBox.shrink()
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Zoom in',
                          icon: Icon(Icons.add,
                              color: _zoom >= _max - 0.001
                                  ? Colors.white38
                                  : Colors.white,
                              size: 20),
                          onPressed:
                              _zoom >= _max - 0.001 ? null : () => _step(1),
                        ),
                        Text('${_zoom.toStringAsFixed(1)}×',
                            style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Zoom out',
                          icon: Icon(Icons.remove,
                              color: _zoom <= _min + 0.001
                                  ? Colors.white38
                                  : Colors.white,
                              size: 20),
                          onPressed:
                              _zoom <= _min + 0.001 ? null : () => _step(-1),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
