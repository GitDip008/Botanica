import 'dart:math';

import 'package:botanica_ar/models/a_star_algorithm.dart';
import 'package:botanica_ar/models/graph_data.dart';
import 'package:botanica_ar/models/mock_plant.dart';
import 'package:botanica_ar/services/plants.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// ============================================================
// DATA MODELS
// ============================================================

/// A point on the map in CAD coordinates (real XY)
class MapPoint {
  final double x;
  final double y;
  const MapPoint(this.x, this.y);
}

/// Path result from A* — ordered list of points in sequence
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

class _IndoorMapScreenState extends State<IndoorMapScreen> with TickerProviderStateMixin {
  // Transform controller to manage pan + zoom
  final TransformationController _transformController =
      TransformationController();
  final GlobalKey _mapKey = GlobalKey();

  final _startXCtrl = TextEditingController();
  final _startYCtrl = TextEditingController();
  final _endXCtrl = TextEditingController();
  final _endYCtrl = TextEditingController();

  NavigationPath _computedPath = [];
  MapPoint? _startMarker;
  MapPoint? _endMarker;
  String _statusMsg = '';
  bool _showInputPanel = false;
  late List<PathNode> _pathNodes;

  // ── New State ──────────────────────────────────────────────
  MapPoint? _tappedPoint; // CAD coordinates of the tapped point
  Offset? _tappedPixel; // Pixel position to display the popup
  bool _showTapPopup = false; // Show/hide popup to choose start/end

  // ── Plant Discovery State ──────────────────────────────────
  List<MockPlantInfo> _discoveredPlants = [];
  bool _isLoadingPlants = false;
  MockPlantInfo? _selectedPlant;
  MockPlantInfo? _editingPlant;
  MapPoint? _tempEditPoint;
  bool _showConfirmEditPopup = false;

  // ── Animation Controllers ──────────────────────────────────
  late AnimationController _mapAnimationController;
  Animation<Matrix4>? _mapMatrixAnimation;

  @override
  void initState() {
    super.initState();
    _pathNodes = List.from(graphPathNodes);
    buildGraphEdges(_pathNodes);
    debugPrint(widget.navigationPath?.length.toString());
    _computedPath = widget.navigationPath ?? [];

    _mapAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mapAnimationController.addListener(() {
      if (_mapMatrixAnimation != null) {
        _transformController.value = _mapMatrixAnimation!.value;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final size = renderBox.size;
      const scale = 1.1;

      final dx = -(size.width * (scale - 1) / 2);
      final dy = -(size.height * (scale - 1) / 2);

      final matrix = Matrix4.identity()
        ..scaleByDouble(scale, scale, scale, 1.0)
        ..translateByVector3(Vector3(dx / scale, dy / scale, 0));

      _transformController.value = matrix;
    });
  }

  @override
  void dispose() {
    _mapAnimationController.dispose();
    _transformController.dispose();
    _startXCtrl.dispose();
    _startYCtrl.dispose();
    _endXCtrl.dispose();
    _endYCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPlants() async {
    if (_isLoadingPlants) return;
    setState(() {
      _isLoadingPlants = true;
      _showTapPopup = false;
    });

    try {
      final plants = await PlantService().fetchNearbyPlants();
      setState(() {
        _discoveredPlants = plants;
        _isLoadingPlants = false;
        _statusMsg = 'Discovered ${plants.length} plants!';
      });
    } catch (e) {
      setState(() {
        _isLoadingPlants = false;
        _statusMsg = 'Failed to fetch plants';
      });
    }
  }

  void _centerOnPlant(MockPlantInfo plant, Size widgetSize) {
    final pixel = cadToPixel(
      point: MapPoint(plant.coordinateX, plant.coordinateY),
      widgetSize: widgetSize,
    );
    const targetScale = 4.0;
    
    final dx = widgetSize.width / 2 - pixel.dx * targetScale;
    final dy = widgetSize.height / 2 - pixel.dy * targetScale;

    final targetMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(targetScale, targetScale, 1.0);

    _animateTransformTo(targetMatrix);
  }

  void _animateTransformTo(Matrix4 targetMatrix) {
    _mapMatrixAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.easeInOutCubic,
    ));
    _mapAnimationController.forward(from: 0.0);
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
      setState(() => _statusMsg = 'Please enter valid coordinates');
      return;
    }

    final startNode = _nearestNode(startX, startY);
    final endNode = _nearestNode(endX, endY);
    final result = AStarAlgorithm().findPath(startNode, endNode);

    if (result.isEmpty) {
      setState(() {
        _statusMsg = 'No path found!';
        _computedPath = [];
        _startMarker = null;
        _endMarker = null;
      });
      return;
    }
    debugPrint('=== A* DEBUG ===');
    debugPrint('Input Start: ($startX, $startY)');
    debugPrint(
      'Nearest Start Node: id=${startNode.id} (${startNode.x}, ${startNode.y})',
    );
    debugPrint('Input End: ($endX, $endY)');
    debugPrint(
      'Nearest End Node:   id=${endNode.id} (${endNode.x}, ${endNode.y})',
    );
    setState(() {
      _statusMsg = '${result.length} nodes';
      _startMarker = MapPoint(startNode.x, startNode.y);
      _endMarker = MapPoint(endNode.x, endNode.y);
      _computedPath = result.map((n) => MapPoint(n.x, n.y)).toList();
      _showInputPanel = false;
    });
  }

  static const double _cadMinX = -177.6683 - 13.7;
  static const double _cadMinY = -14.3375;
  static const double _cadMaxX = -120.9942;
  static const double _cadMaxY = 23.6977 + 15.7;
  static const double _cadW = 84;
  static const double _cadH = 40.0352;

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

    final normalizedX = (pixel.dx - offsetX) / scale;
    final normalizedY = (pixel.dy - offsetY) / scale;
    final cadX = normalizedX / mapW * _cadW + _cadMinX;
    final cadY = _cadMaxY - normalizedY / mapH * _cadH;

    return MapPoint(cadX, cadY);
  }

  void _onMapTap(TapDownDetails details, Size widgetSize) {
    // Use _mapKey to get the correct RenderBox of the InteractiveViewer
    final RenderBox? box =
        _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Convert global position to local position of InteractiveViewer
    final localPos = box.globalToLocal(details.globalPosition);

    // Inverse transform to revert to original coordinates before zoom/pan
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(inverseMatrix, localPos);

    final cad = pixelToCad(transformed, widgetSize);

    if (_editingPlant != null) {
      setState(() {
        _tempEditPoint = cad;
        _tappedPixel = details.localPosition; // Keep original localPosition to show the popup at the correct position
        _showConfirmEditPopup = true;
        _showTapPopup = false; // Hide regular tap popup
      });
      return;
    }

    setState(() {
      _tappedPoint = cad;
      _tappedPixel =
          details.localPosition; // Keep original localPosition to show the popup at the correct position
      _showTapPopup = true;
      _selectedPlant = null;
    });
  }

  void _dismissPopup() {
    setState(() => _showTapPopup = false);
  }

  void _setAsStart() {
    if (_tappedPoint == null) return;
    setState(() {
      _startXCtrl.text = _tappedPoint!.x.toStringAsFixed(2);
      _startYCtrl.text = _tappedPoint!.y.toStringAsFixed(2);
      _showTapPopup = false;
      // Open input panel so the user sees the filled values
      _showInputPanel = true;
    });
  }

  void _setAsDestination() {
    if (_tappedPoint == null) return;
    setState(() {
      _endXCtrl.text = _tappedPoint!.x.toStringAsFixed(2);
      _endYCtrl.text = _tappedPoint!.y.toStringAsFixed(2);
      _showTapPopup = false;
      _showInputPanel = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text(
          'Indoor Navigation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_statusMsg.isNotEmpty && _computedPath.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _statusMsg,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: _isLoadingPlants
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.local_florist_outlined),
            tooltip: 'Discover Plants',
            onPressed: _isLoadingPlants ? null : _fetchPlants,
          ),
          IconButton(
            icon: Icon(
              _showInputPanel ? Icons.close : Icons.search,
              color: _showInputPanel ? const Color(0xFFEF5350) : Colors.white,
            ),
            tooltip: _showInputPanel ? 'Close' : 'Find Route',
            onPressed: () => setState(() {
              _showInputPanel = !_showInputPanel;
              _showTapPopup = false; // Close popup when opening the panel
            }),
          ),
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
              // ── Map + GestureDetector ─────────────────────
              GestureDetector(
                onTapDown: (details) => _onMapTap(details, widgetSize),
                child: InteractiveViewer(
                  key: _mapKey, // added here
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 50,
                  boundaryMargin: const EdgeInsets.all(100),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: widgetSize.width,
                        height: widgetSize.height,
                        child: Image.asset(
                          widget.imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
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
                      if (_startMarker != null)
                        _buildMarker(
                          point: _startMarker!,
                          widgetSize: widgetSize,
                          width: 30.0,
                          height: 30.0,
                          anchorX: 0.5,
                          anchorY: 0.5,
                          child: _UserMarker(),
                        ),
                      if (_endMarker != null && _selectedPlant == null)
                        _buildMarker(
                          point: _endMarker!,
                          widgetSize: widgetSize,
                          width: 20.0,
                          height: 20.0,
                          anchorX: 0.5,
                          anchorY: 1.0,
                          child: _DestinationMarker(),
                        ),
                      for (final plant in _discoveredPlants)
                        _buildMarker(
                          point: MapPoint(plant.coordinateX, plant.coordinateY),
                          widgetSize: widgetSize,
                          width: 10.0,
                          height: 10.0,
                          anchorX: 0.5,
                          anchorY: 0.5,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPlant = plant;
                                _endXCtrl.text = plant.coordinateX.toStringAsFixed(2);
                                _endYCtrl.text = plant.coordinateY.toStringAsFixed(2);
                                _runAStar();
                              });
                              _centerOnPlant(plant, widgetSize);
                            },
                            child: TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 500),
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              curve: Curves.elasticOut,
                              builder: (context, val, child) {
                                final isSelected = _selectedPlant?.plantId == plant.plantId;
                                return Transform.scale(
                                  scale: val * (isSelected ? 1.3 : 1.0),
                                  child: child,
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32),
                                    width: 1.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 3,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(1),
                                child: const Icon(
                                  Icons.local_florist,
                                  color: Color(0xFF2E7D32),
                                  size: 5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_editingPlant != null && _tempEditPoint != null)
                        _buildMarker(
                          point: _tempEditPoint!,
                          widgetSize: widgetSize,
                          width: 10.0,
                          height: 10.0,
                          anchorX: 0.5,
                          anchorY: 0.5,
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, val, child) => Transform.scale(
                              scale: val,
                              child: child,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFEF5350), width: 0.7),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(1),
                              child: const Icon(
                                Icons.place,
                                color: Color(0xFFEF5350),
                                size: 5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Tap Popup ─────────────────────────────────
              if (_showTapPopup && _tappedPixel != null && _tappedPoint != null)
                _buildTapPopup(widgetSize),

              // ── Confirm Edit Popup ────────────────────────
              if (_showConfirmEditPopup && _tappedPixel != null && _tempEditPoint != null && _editingPlant != null)
                _buildConfirmEditPopup(widgetSize),

              // ── Input Panel ───────────────────────────────
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

              // ── Discovered Plants List Panel ─────────────────────────────
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: AnimatedSlide(
                  offset: _discoveredPlants.isNotEmpty ? Offset.zero : const Offset(0, 1.5),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _discoveredPlants.isNotEmpty ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _buildPlantsListPanel(widgetSize),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlantsListPanel(Size widgetSize) {
    return Container(
      height: 165,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_florist,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Nearby Discoveries',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _discoveredPlants = [];
                      _selectedPlant = null;
                      _editingPlant = null;
                      _tempEditPoint = null;
                      _showConfirmEditPopup = false;
                    });
                  },
                  child: const Icon(
                    Icons.close,
                    color: Colors.white60,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Horizontal list of plants
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _discoveredPlants.length,
              itemBuilder: (context, index) {
                final plant = _discoveredPlants[index];
                final isSelected = _selectedPlant?.plantId == plant.plantId;
                final isEditingThis = _editingPlant?.plantId == plant.plantId;

                return GestureDetector(
                  onTap: () {
                    if (_editingPlant != null) return; // Ignore selection during edit
                    setState(() {
                      _selectedPlant = plant;
                      _endXCtrl.text = plant.coordinateX.toStringAsFixed(2);
                      _endYCtrl.text = plant.coordinateY.toStringAsFixed(2);
                      _runAStar(); // automatically run A* path
                    });
                    _centerOnPlant(plant, widgetSize);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 170,
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEditingThis
                          ? const Color(0xFFEF5350).withOpacity(0.15)
                          : (isSelected
                              ? Theme.of(context).colorScheme.secondary.withOpacity(0.15)
                              : Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEditingThis
                            ? const Color(0xFFEF5350)
                            : (isSelected
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.white12),
                        width: (isSelected || isEditingThis) ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.eco,
                              color: isEditingThis
                                  ? const Color(0xFFEF5350)
                                  : (isSelected
                                      ? Theme.of(context).colorScheme.secondary
                                      : Colors.white70),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                plant.plantName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'X: ${plant.coordinateX.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'Y: ${plant.coordinateY.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isEditingThis) {
                                _editingPlant = null;
                                _tempEditPoint = null;
                                _showConfirmEditPopup = false;
                              } else {
                                _editingPlant = plant;
                                _tempEditPoint = null;
                                _showConfirmEditPopup = false;
                                _statusMsg = 'Click on map to select position';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isEditingThis
                                  ? const Color(0xFFEF5350)
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                isEditingThis ? 'Choose Position' : 'Edit Location',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmEditPopup(Size widgetSize) {
    if (_tempEditPoint == null || _editingPlant == null) return const SizedBox.shrink();

    final pixel = cadToPixel(point: _tempEditPoint!, widgetSize: widgetSize);

    const popupW = 200.0;
    const popupH = 125.0;
    const margin = 8.0;

    double left = pixel.dx - popupW / 2;
    double top = pixel.dy - popupH - 12;

    left = left.clamp(margin, widgetSize.width - popupW - margin);
    top = top.clamp(margin, widgetSize.height - popupH - margin);

    return Positioned(
      left: left,
      top: top,
      width: popupW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Location Update',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white12, height: 10),
              Text(
                'Update "${_editingPlant!.plantName}" to:',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'X: ${_tempEditPoint!.x.toStringAsFixed(2)}\nY: ${_tempEditPoint!.y.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Call the mock API update function
                        PlantService().editPlantInformationById(
                          _editingPlant!.plantId,
                          _tempEditPoint!.x,
                          _tempEditPoint!.y,
                        );

                        setState(() {
                          final updatedList = _discoveredPlants.map((p) {
                            if (p.plantId == _editingPlant!.plantId) {
                              return MockPlantInfo(
                                plantId: p.plantId,
                                plantName: p.plantName,
                                coordinateX: _tempEditPoint!.x,
                                coordinateY: _tempEditPoint!.y,
                              );
                            }
                            return p;
                          }).toList();
                          _discoveredPlants = updatedList;

                          if (_selectedPlant?.plantId == _editingPlant!.plantId) {
                            _selectedPlant = updatedList.firstWhere((p) => p.plantId == _editingPlant!.plantId);
                            _endXCtrl.text = _selectedPlant!.coordinateX.toStringAsFixed(2);
                            _endYCtrl.text = _selectedPlant!.coordinateY.toStringAsFixed(2);
                            _runAStar();
                          }

                          _statusMsg = 'Updated ${_editingPlant!.plantName} location';
                          _editingPlant = null;
                          _tempEditPoint = null;
                          _showConfirmEditPopup = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingPlant = null;
                          _tempEditPoint = null;
                          _showConfirmEditPopup = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF5350), width: 0.8),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapPopup(Size widgetSize) {
    const popupW = 200.0;
    const popupH = 110.0;
    const margin = 8.0;

    // Calculate popup position — display above the tap point, centered on X
    double left = _tappedPixel!.dx - popupW / 2;
    double top = _tappedPixel!.dy - popupH - 12;

    // Avoid going off screen
    left = left.clamp(margin, widgetSize.width - popupW - margin);
    top = top.clamp(margin, widgetSize.height - popupH - margin);

    return Positioned(
      left: left,
      top: top,
      width: popupW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selected Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismissPopup,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 10),
              // CAD Coordinates
              Text(
                'X: ${_tappedPoint!.x.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                'Y: ${_tappedPoint!.y.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 8),
              // Question
              const Text(
                'Set as:',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 6),
              // 2 buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _setAsStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Start',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: _setAsDestination,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFEF5350),
                            width: 0.8,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Destination',
                            style: TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.97),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Theme.of(context).colorScheme.secondary, size: 16),
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
          if (_statusMsg.isNotEmpty && _computedPath.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _statusMsg,
                style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.route, size: 16),
              label: const Text(
                'Find Route',
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
        fillColor: Theme.of(context).scaffoldBackgroundColor,
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
    required double width,
    required double height,
    double anchorX = 0.5,
    double anchorY = 1.0,
  }) {
    final pixel = cadToPixel(point: point, widgetSize: widgetSize);
    return Positioned(
      left: pixel.dx - width * anchorX,
      top: pixel.dy - height * anchorY,
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _buildInfoBar() {
    final hasPath =
        widget.navigationPath != null && widget.navigationPath!.isNotEmpty;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // User position info
            Icon(Icons.my_location, color: Theme.of(context).colorScheme.secondary, size: 8),
            const SizedBox(width: 8),
            Text(
              widget.userPosition != null
                  ? 'User: (${widget.userPosition!.x.toStringAsFixed(1)}, ${widget.userPosition!.y.toStringAsFixed(1)})'
                  : 'User: –',
              style: const TextStyle(color: Colors.white70, fontSize: 8),
            ),
            const SizedBox(width: 16),
            // Destination info
            const Icon(Icons.place, color: Color(0xFFEF5350), size: 8),
            const SizedBox(width: 8),
            Text(
              widget.destination != null
                  ? 'Dest: (${widget.destination!.x.toStringAsFixed(1)}, ${widget.destination!.y.toStringAsFixed(1)})'
                  : 'Dest: –',
              style: const TextStyle(color: Colors.white70, fontSize: 9),
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
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.navigationPath!.length} nodes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
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
// USER MARKER — green dot with pulse animation
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
            width: 30 * _pulse.value,
            height: 30 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF66BB6A).withOpacity(0.3 * (1 - _pulse.value + 0.5)),
            ),
          ),
          // Core dot
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E7D32),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.6),
                  blurRadius: 5,
                  spreadRadius: 1,
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
// DESTINATION MARKER — custom plant pin
// ============================================================

class _DestinationMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Small shadow at base
        Container(
          width: 6,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(6, 3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        // Pin body
        Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF5350),
            border: Border.all(color: Colors.white, width: 0.7),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF5350).withOpacity(0.4),
                blurRadius: 3,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: const Icon(
            Icons.eco, // beautiful botanical leaf icon
            color: Colors.white,
            size: 5,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PATH PAINTER — draws A* path on canvas
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

    // ── Draw path shadow ────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final shadowPath = _buildPath();
    canvas.drawPath(shadowPath, shadowPaint);

    // ── Draw main path ─────────────────────────────────────
    final pathPaint = Paint()
      ..color = const Color(0xFF66BB6A) // secondary plant green
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(shadowPath, pathPaint);
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
