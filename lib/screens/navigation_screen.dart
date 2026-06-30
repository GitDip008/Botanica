import 'dart:math';

import 'package:botanica_ar/models/a_star_algorithm.dart';
import 'package:botanica_ar/models/graph_data.dart';
import 'package:flutter/material.dart';

// ============================================================
// DATA MODELS
// ============================================================

/// Một điểm trên bản đồ theo tọa độ CAD (XY thực)
class MapPoint {
  final double x;
  final double y;
  const MapPoint(this.x, this.y);
}

/// Kết quả path từ A* — list các điểm theo thứ tự
typedef NavigationPath = List<MapPoint>;

// ============================================================
// MAP SCREEN
// ============================================================

class IndoorMapScreen extends StatefulWidget {
  final String imagePath;
  final Size mapSize;
  final MapPoint? userPosition;
  final MapPoint? destination;
  final NavigationPath? navigationPath;
  final List<MapPoint>? graphNodes;
  final List<List<int>>? graphEdges;

  const IndoorMapScreen({
    super.key,
    this.imagePath = 'greenhouse.png',
    required this.mapSize,
    this.userPosition,
    this.destination,
    this.navigationPath,
    this.graphNodes,
    this.graphEdges,
  });

  @override
  State<IndoorMapScreen> createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends State<IndoorMapScreen> {
  // Transform controller để quản lý pan + zoom
  final TransformationController _transformController =
      TransformationController();

  final _startXCtrl = TextEditingController();
  final _startYCtrl = TextEditingController();
  final _endXCtrl = TextEditingController();
  final _endYCtrl = TextEditingController();

  NavigationPath _computedPath = [];
  MapPoint? _startMarker;
  MapPoint? _endMarker;
  String _statusMsg = '';
  bool _showInputPanel = false; // toggle ẩn/hiện panel
  late List<PathNode> _pathNodes;

  @override
  void initState() {
    super.initState();
    _pathNodes = List.from(graphPathNodes);
    buildGraphEdges(_pathNodes);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _startXCtrl.dispose();
    _startYCtrl.dispose();
    _endXCtrl.dispose();
    _endYCtrl.dispose();
    super.dispose();
  }

  PathNode _nearestNode(double x, double y) {
    PathNode? best;
    double bestDist = double.infinity;
    for (final n in _pathNodes) {
      final dx = n.x - x;
      final dy = n.y - y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = n;
      }
    }
    return best!;
  }

  void _runAStar() {
    final startX = double.tryParse(_startXCtrl.text);
    final startY = double.tryParse(_startYCtrl.text);
    final endX = double.tryParse(_endXCtrl.text);
    final endY = double.tryParse(_endYCtrl.text);

    if (startX == null || startY == null || endX == null || endY == null) {
      setState(() => _statusMsg = 'Nhập đầy đủ tọa độ hợp lệ');
      return;
    }

    final startNode = _nearestNode(startX, startY);
    final endNode = _nearestNode(endX, endY);
    final result = AStarAlgorithm().findPath(startNode, endNode);

    if (result.isEmpty) {
      setState(() {
        _statusMsg = 'Không tìm được đường đi!';
        _computedPath = [];
        _startMarker = null;
        _endMarker = null;
      });
      return;
    }

    setState(() {
      _statusMsg = '${result.length} nodes';
      _startMarker = MapPoint(startNode.x, startNode.y);
      _endMarker = MapPoint(endNode.x, endNode.y);
      _computedPath = result.map((n) => MapPoint(n.x, n.y)).toList();
      _showInputPanel = false; // tự đóng panel sau khi search
    });
  }

  // ── Chuyển tọa độ CAD (x, y) → pixel trên widget ──────────
  //
  // Vì SVG được render vừa khít trong widget (BoxFit.contain),
  // ta cần tính scale và offset để biết điểm (x, y) trong CAD
  // nằm ở pixel nào trên màn hình.
  //
  // Công thức:
  //   pixelX = offsetX + (cadX / mapWidth)  * renderedWidth
  //   pixelY = offsetY + (cadY / mapHeight) * renderedHeight
  //
  static const double _cadMinX = -177.6683 - 14.5; // shift phải
  static const double _cadMinY = -14.3375;
  static const double _cadMaxX = -120.9942 - 2.0; // giữ width không đổi
  static const double _cadMaxY = 23.6977 + 16; // shift lên
  static const double _cadW = 86; // giữ nguyên
  static const double _cadH = 40.0352; // giữ nguyên

  Offset cadToPixel({required MapPoint point, required Size widgetSize}) {
    final mapW = widget.mapSize.width;
    final mapH = widget.mapSize.height;
    final widgetW = widgetSize.width;
    final widgetH = widgetSize.height;

    final scaleX = widgetW / mapW;
    final scaleY = widgetH / mapH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final renderedW = mapW * scale;
    final renderedH = mapH * scale;

    final offsetX = (widgetW - renderedW) / 2;
    final offsetY = (widgetH - renderedH) / 2;

    final normalizedX = (point.x - _cadMinX) / _cadW * mapW;
    final normalizedY = (_cadMaxY - point.y) / _cadH * mapH;

    return Offset(offsetX + normalizedX * scale, offsetY + normalizedY * scale);
  }

  MapPoint pixelToCad(Offset pixel, Size widgetSize) {
    final mapW = widget.mapSize.width;
    final mapH = widget.mapSize.height;
    final widgetW = widgetSize.width;
    final widgetH = widgetSize.height;

    final scaleX = widgetW / mapW;
    final scaleY = widgetH / mapH;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final renderedW = mapW * scale;
    final renderedH = mapH * scale;

    final offsetX = (widgetW - renderedW) / 2;
    final offsetY = (widgetH - renderedH) / 2;

    // Đảo ngược lại normalizedX, normalizedY từ cadToPixel
    final normalizedX = (pixel.dx - offsetX) / scale;
    final normalizedY = (pixel.dy - offsetY) / scale;

    // Đảo ngược lại point.x, point.y
    final cadX = normalizedX / mapW * _cadW + _cadMinX;
    final cadY = _cadMaxY - normalizedY / mapH * _cadH;

    return MapPoint(cadX, cadY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Indoor Navigation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Status badge
          if (_statusMsg.isNotEmpty && _computedPath.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusMsg,
                  style: const TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // Toggle input panel button
          IconButton(
            icon: Icon(
              _showInputPanel ? Icons.close : Icons.search,
              color: _showInputPanel ? const Color(0xFFEF5350) : Colors.white,
            ),
            tooltip: _showInputPanel ? 'Đóng' : 'Tìm đường',
            onPressed: () => setState(() => _showInputPanel = !_showInputPanel),
          ),

          // Reset view
          IconButton(
            icon: const Icon(Icons.center_focus_strong_outlined),
            tooltip: 'Reset view',
            onPressed: () => _transformController.value = Matrix4.identity(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final widgetSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              // ── Map layer ─────────────────────────────────
              GestureDetector(
                onTapDown: (details) {
                  // Lấy tọa độ tap trong hệ widget (chưa bị zoom/pan ảnh hưởng)
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);

                  // Lấy current transform matrix của InteractiveViewer
                  final matrix = _transformController.value;
                  final inverseMatrix = Matrix4.inverted(matrix);

                  // Áp inverse transform để quy về tọa độ gốc trước khi zoom/pan
                  final transformed = MatrixUtils.transformPoint(
                    inverseMatrix,
                    localPos,
                  );

                  final cad = pixelToCad(transformed, widgetSize);
                  debugPrint(
                    'CAD: (${cad.x.toStringAsFixed(2)}, ${cad.y.toStringAsFixed(2)})',
                  );
                },
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(100),
                  child: Stack(
                    children: [
                      // Layer 1: Map image
                      SizedBox(
                        width: widgetSize.width,
                        height: widgetSize.height,
                        child: Image.asset(
                          widget.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // Layer 2: Graph edges
                      if (widget.graphNodes != null &&
                          widget.graphEdges != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GraphPainter(
                              nodes: widget.graphNodes!,
                              edges: widget.graphEdges!,
                              widgetSize: widgetSize,
                              cadToPixel: (p) =>
                                  cadToPixel(point: p, widgetSize: widgetSize),
                            ),
                          ),
                        ),

                      // Layer 3: A* path
                      if (_computedPath.length >= 2)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PathPainter(
                              path: _computedPath,
                              widgetSize: widgetSize,
                              cadToPixel: (p) =>
                                  cadToPixel(point: p, widgetSize: widgetSize),
                            ),
                          ),
                        ),

                      // Layer 4: Start marker
                      if (_startMarker != null)
                        _buildMarker(
                          point: _startMarker!,
                          widgetSize: widgetSize,
                          anchorY: 0.5,
                          child: const Icon(
                            Icons.my_location,
                            color: Color(0xFF4FC3F7),
                            size: 20,
                          ),
                        ),

                      // Layer 5: End marker
                      if (_endMarker != null)
                        _buildMarker(
                          point: _endMarker!,
                          widgetSize: widgetSize,
                          child: const Icon(
                            Icons.location_pin,
                            color: Color(0xFFEF5350),
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Input panel overlay (slide down) ──────────
              AnimatedSlide(
                offset: _showInputPanel ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _showInputPanel ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: _buildInputPanel(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: const Color(0xFF16213E).withOpacity(0.97),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Start row
          Row(
            children: [
              const Icon(Icons.my_location, color: Color(0xFF4FC3F7), size: 16),
              const SizedBox(width: 8),
              const SizedBox(
                width: 36,
                child: Text(
                  'Start',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_startXCtrl, 'X')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_startYCtrl, 'Y')),
            ],
          ),
          const SizedBox(height: 8),
          // End row
          Row(
            children: [
              const Icon(
                Icons.location_pin,
                color: Color(0xFFEF5350),
                size: 16,
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 36,
                child: Text(
                  'End',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_endXCtrl, 'X')),
              const SizedBox(width: 8),
              Expanded(child: _inputField(_endYCtrl, 'Y')),
            ],
          ),
          const SizedBox(height: 10),
          // Error msg
          if (_statusMsg.isNotEmpty && _computedPath.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _statusMsg,
                style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
              ),
            ),
          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7),
                foregroundColor: const Color(0xFF1A1A2E),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.route, size: 16),
              label: const Text(
                'Tìm đường',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: _runAStar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: const Color(0xFF0F3460),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildMarker({
    required MapPoint point,
    required Size widgetSize,
    required Widget child,
    double anchorX = 0.5,
    double anchorY = 1.0,
  }) {
    final pixel = cadToPixel(point: point, widgetSize: widgetSize);
    const markerSize = 24.0;
    return Positioned(
      left: pixel.dx - markerSize * anchorX,
      top: pixel.dy - markerSize * anchorY,
      width: markerSize,
      height: markerSize,
      child: child,
    );
  }

  Widget _buildInfoBar() {
    final hasPath =
        widget.navigationPath != null && widget.navigationPath!.isNotEmpty;

    return Container(
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // User position info
            const Icon(Icons.my_location, color: Color(0xFF4FC3F7), size: 18),
            const SizedBox(width: 8),
            Text(
              widget.userPosition != null
                  ? 'User: (${widget.userPosition!.x.toStringAsFixed(1)}, ${widget.userPosition!.y.toStringAsFixed(1)})'
                  : 'User: –',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(width: 16),
            // Destination info
            const Icon(Icons.place, color: Color(0xFFEF5350), size: 18),
            const SizedBox(width: 8),
            Text(
              widget.destination != null
                  ? 'Dest: (${widget.destination!.x.toStringAsFixed(1)}, ${widget.destination!.y.toStringAsFixed(1)})'
                  : 'Dest: –',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Spacer(),
            // Path node count
            if (hasPath)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3460),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.navigationPath!.length} nodes',
                  style: const TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// USER MARKER — dot xanh với pulse animation
// ============================================================

class _UserMarker extends StatefulWidget {
  @override
  State<_UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<_UserMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          Container(
            width: 40 * _pulse.value,
            height: 40 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF4FC3F7,
              ).withOpacity(0.3 * (1 - _pulse.value + 0.5)),
            ),
          ),
          // Core dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4FC3F7),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DESTINATION MARKER — pin đỏ
// ============================================================

class _DestinationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_pin,
      color: Color(0xFFEF5350),
      size: 40,
      shadows: [
        Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
      ],
    );
  }
}

// ============================================================
// PATH PAINTER — vẽ đường A* lên canvas
// ============================================================

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

    // ── Vẽ shadow của path ────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final shadowPath = _buildPath();
    canvas.drawPath(shadowPath, shadowPaint);

    // ── Vẽ path chính ─────────────────────────────────────
    final pathPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(shadowPath, pathPaint);

    // ── Vẽ dots tại mỗi node ──────────────────────────────
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i < path.length - 1; i++) {
      final pixel = cadToPixel(path[i]);
      canvas.drawCircle(pixel, 1, dotPaint);
      canvas.drawCircle(pixel, 1, dotBorderPaint);
    }
  }

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
    // Vẽ edges
    final edgePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final edge in edges) {
      final p1 = cadToPixel(nodes[edge[0]]);
      final p2 = cadToPixel(nodes[edge[1]]);
      canvas.drawLine(p1, p2, edgePaint);
    }

    // Vẽ nodes
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final nodeBorderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final node in nodes) {
      final pixel = cadToPixel(node);
      canvas.drawCircle(pixel, 3, nodePaint);
      canvas.drawCircle(pixel, 3, nodeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) => false;
}
