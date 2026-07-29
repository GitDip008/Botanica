/// PURPOSE:
/// This file implements the PathPainter CustomPainter which draws the computed A* path
/// route on the map canvas. It displays a solid green line with a shadow glow.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map painting.
///
/// INPUTS / PARAMETERS:
/// - path (NavigationPath, Required): The sequence of MapPoint coordinates representing the path.
/// - widgetSize (Size, Required): The viewport dimension to scale the painting correctly.
/// - cadToPixel (Offset Function(MapPoint), Required): Transformation callback converting CAD space to pixel space.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../navigation_screen.dart' show MapPoint, NavigationPath;

class PathPainter extends CustomPainter {
  final NavigationPath path;
  final Size widgetSize;
  final Offset Function(MapPoint) cadToPixel;

  PathPainter({
    required this.path,
    required this.widgetSize,
    required this.cadToPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    // Draw path shadow
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final shadowPath = _buildPath();
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw main path line
    final pathPaint = Paint()
      ..color = const Color(0xFF66BB6A) // secondary plant green
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(shadowPath, pathPaint);
  }

  /// BEHAVIORAL MECHANISM:
  /// Constructs a Flutter Path object by mapping each MapPoint CAD coordinate to the corresponding
  /// screen pixel coordinate, starting with a moveTo for the first node and lineTo for all subsequent nodes.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Path: The complete Flutter Path object containing lines joining all mapped node points.
  Path _buildPath() {
    final flutterPath = Path();
    final first = cadToPixel(path[0]);
    flutterPath.moveTo(first.dx, first.dy);
    for (int i = 1; i < path.length; i++) {
      final pixel = cadToPixel(path[i]);
      flutterPath.lineTo(pixel.dx, pixel.dy);
    }
    return flutterPath;
  }

  @override
  bool shouldRepaint(PathPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.widgetSize != widgetSize;
}
