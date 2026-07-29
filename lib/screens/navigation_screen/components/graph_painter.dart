/// PURPOSE:
/// This file implements the GraphPainter CustomPainter which draws the entire path network graph
/// (nodes and edges) in the greenhouse background.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map painting.
///
/// INPUTS / PARAMETERS:
/// - nodes (List<MapPoint>, Required): All node positions.
/// - edges (List<List<int>>, Required): Adjacency list mapping node index connections.
/// - widgetSize (Size, Required): Viewport dimensions.
/// - cadToPixel (Offset Function(MapPoint), Required): Transformation mapping CAD space to pixel space.

import 'package:flutter/material.dart';
import '../navigation_screen.dart' show MapPoint;

class GraphPainter extends CustomPainter {
  final List<MapPoint> nodes;
  final List<List<int>> edges;
  final Size widgetSize;
  final Offset Function(MapPoint) cadToPixel;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.widgetSize,
    required this.cadToPixel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges
    final edgePaint = Paint()
      ..color = const Color(0xFF66BB6A).withOpacity(0.3)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final p1 = cadToPixel(nodes[edge[0]]);
      final p2 = cadToPixel(nodes[edge[1]]);
      canvas.drawLine(p1, p2, edgePaint);
    }

    // Draw nodes
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = const Color(0xFF66BB6A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final node in nodes) {
      final pixel = cadToPixel(node);
      canvas.drawCircle(pixel, 2.0, nodePaint);
      canvas.drawCircle(pixel, 2.0, nodeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) => false;
}
