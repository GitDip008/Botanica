/// PURPOSE:
/// This file implements the main IndoorMapScreen screen, which provides interactive
/// indoor navigation inside the greenhouse using a vector map, A* routing, and real-time
/// user positioning via Bluetooth Beacons (weighted KNN fingerprinting).
///
/// CONTEXT/PARENT FILE:
/// Parent navigation screen file refactored to decompose monolithic sub-widgets into components.
///
/// INPUTS / PARAMETERS:
/// - imagePath (String, Required): Asset path for the greenhouse floor plan map image.
/// - mapSize (Size, Required): Original dimensions of the map image.
/// - graphNodes (List<PathNode>?, Optional): List of nodes representing path intersection coordinates.
/// - graphEdges (List<List<int>>?, Optional): Adjacency list mapping node index connections.
/// - navigationPath (NavigationPath?, Optional): Default computed navigation path.
/// - userPosition (MapPoint?, Optional): Initial user location CAD coordinate.
/// - destination (MapPoint?, Optional): Initial destination location CAD coordinate.

import 'dart:async';
import 'dart:math';

import 'package:botanica_ar/models/a_star_algorithm.dart';
import 'package:botanica_ar/models/graph_data.dart';
import 'package:botanica_ar/models/mock_plant.dart';
import 'package:botanica_ar/models/finger_print_algorithm.dart';
import 'package:botanica_ar/services/beacons_service.dart';
import 'package:botanica_ar/services/plants.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

// Import local components
import 'components/user_marker.dart';
import 'components/destination_marker.dart';
import 'components/path_painter.dart';
import 'components/graph_painter.dart';
import 'components/plants_list_panel.dart';
import 'components/input_panel.dart';
import 'components/info_bar.dart';
import 'components/confirm_edit_popup.dart';
import 'components/tap_popup.dart';

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
  final TransformationController _transformController = TransformationController();
  final GlobalKey _mapKey = GlobalKey();

  final TextEditingController _startXCtrl = TextEditingController();
  final TextEditingController _startYCtrl = TextEditingController();
  final TextEditingController _endXCtrl = TextEditingController();
  final TextEditingController _endYCtrl = TextEditingController();

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

  // ── BLE & Fingerprint Positioning State ──────────────────────
  static final List<SurveyPoint> _surveyDataPoints = [
    SurveyPoint(id: '1', x: -156.9031, y: 9.3709, rssi: {'romeoE': -90, 'juliaE': -85, 'mainEntrance': -92, 'juliaC': -83, 'juliaE2': -97, 'juliaF': -98, 'romeoB': -96}),
    SurveyPoint(id: '2', x: -156.9031, y: 8.2400, rssi: {'romeoE': -93, 'juliaE': -82, 'mainEntrance': -90, 'juliaC': -84, 'juliaE2': null, 'juliaF': -93, 'romeoB': null}),
    SurveyPoint(id: '3', x: -156.9031, y: 5.7726, rssi: {'romeoE': -90, 'juliaE': -75, 'mainEntrance': -88, 'juliaC': -84, 'juliaE2': null, 'juliaF': -92, 'romeoB': null}),
    SurveyPoint(id: '4', x: -156.9031, y: 4.5478, rssi: {'romeoE': -94, 'juliaE': -85, 'mainEntrance': -90, 'juliaC': -89, 'juliaE2': -94, 'juliaF': -92, 'romeoB': null}),
    SurveyPoint(id: '5', x: -156.9031, y: 3.4640, rssi: {'romeoE': -95, 'juliaE': -79, 'mainEntrance': -89, 'juliaC': -87, 'juliaE2': -89, 'juliaF': -92, 'romeoB': null}),
    SurveyPoint(id: '6', x: -156.9031, y: 1.4283, rssi: {'romeoE': null, 'juliaE': -57, 'mainEntrance': null, 'juliaC': -80, 'juliaE2': -97, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '7', x: -154.7872, y: 1.4283, rssi: {'romeoE': null, 'juliaE': -60, 'mainEntrance': null, 'juliaC': -82, 'juliaE2': -93, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '8', x: -152.9914, y: 0.5041, rssi: {'romeoE': null, 'juliaE': -74, 'mainEntrance': null, 'juliaC': -80, 'juliaE2': -90, 'juliaF': -90, 'romeoB': null}),
    SurveyPoint(id: '9', x: -152.9914, y: -0.5457, rssi: {'romeoE': null, 'juliaE': -74, 'mainEntrance': null, 'juliaC': -78, 'juliaE2': -97, 'juliaF': -83, 'romeoB': null}),
    SurveyPoint(id: '10', x: -154.3981, y: -2.3533, rssi: {'romeoE': null, 'juliaE': -77, 'mainEntrance': null, 'juliaC': -80, 'juliaE2': -88, 'juliaF': -78, 'romeoB': null}),
    SurveyPoint(id: '11', x: -155.5456, y: -3.7046, rssi: {'romeoE': null, 'juliaE': -76, 'mainEntrance': null, 'juliaC': -77, 'juliaE2': -91, 'juliaF': -74, 'romeoB': null}),
    SurveyPoint(id: '12', x: -155.7224, y: -5.8381, rssi: {'romeoE': null, 'juliaE': -80, 'mainEntrance': null, 'juliaC': -77, 'juliaE2': -88, 'juliaF': -68, 'romeoB': null}),
    SurveyPoint(id: '13', x: -154.8198, y: -6.4770, rssi: {'romeoE': null, 'juliaE': -85, 'mainEntrance': null, 'juliaC': -82, 'juliaE2': -90, 'juliaF': -74, 'romeoB': null}),
    SurveyPoint(id: '14', x: -153.2036, y: -7.7970, rssi: {'romeoE': null, 'juliaE': -82, 'mainEntrance': null, 'juliaC': -78, 'juliaE2': -85, 'juliaF': -74, 'romeoB': null}),
    SurveyPoint(id: '15', x: -153.0807, y: -9.8647, rssi: {'romeoE': null, 'juliaE': -90, 'mainEntrance': null, 'juliaC': -81, 'juliaE2': -91, 'juliaF': -78, 'romeoB': null}),
    SurveyPoint(id: '16', x: -154.6755, y: -11.1845, rssi: {'romeoE': null, 'juliaE': -87, 'mainEntrance': null, 'juliaC': -81, 'juliaE2': -90, 'juliaF': -75, 'romeoB': null}),
    SurveyPoint(id: '17', x: -156.7666, y: -11.1845, rssi: {'romeoE': null, 'juliaE': -95, 'mainEntrance': null, 'juliaC': -84, 'juliaE2': -90, 'juliaF': -83, 'romeoB': null}),
    SurveyPoint(id: '18', x: -157.9130, y: -9.3514, rssi: {'romeoE': null, 'juliaE': -90, 'mainEntrance': null, 'juliaC': -81, 'juliaE2': -88, 'juliaF': -73, 'romeoB': null}),
    SurveyPoint(id: '19', x: -159.9725, y: -8.7493, rssi: {'romeoE': null, 'juliaE': -90, 'mainEntrance': null, 'juliaC': -82, 'juliaE2': -76, 'juliaF': -77, 'romeoB': null}),
    SurveyPoint(id: '20', x: -161.9356, y: -9.6298, rssi: {'romeoE': null, 'juliaE': -94, 'mainEntrance': null, 'juliaC': -82, 'juliaE2': -83, 'juliaF': -86, 'romeoB': null}),
    SurveyPoint(id: '21', x: -163.6133, y: -11.1595, rssi: {'romeoE': null, 'juliaE': -88, 'mainEntrance': null, 'juliaC': -86, 'juliaE2': -76, 'juliaF': -82, 'romeoB': null}),
    SurveyPoint(id: '22', x: -165.4555, y: -10.4879, rssi: {'romeoE': null, 'juliaE': -90, 'mainEntrance': null, 'juliaC': -86, 'juliaE2': -72, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '23', x: -165.7451, y: -8.3255, rssi: {'romeoE': null, 'juliaE': -89, 'mainEntrance': null, 'juliaC': -87, 'juliaE2': -66, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '24', x: -165.7864, y: -4.1967, rssi: {'romeoE': null, 'juliaE': -83, 'mainEntrance': null, 'juliaC': -80, 'juliaE2': -80, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '25', x: -164.8322, y: -2.4118, rssi: {'romeoE': null, 'juliaE': -79, 'mainEntrance': null, 'juliaC': -86, 'juliaE2': -75, 'juliaF': -88, 'romeoB': null}),
    SurveyPoint(id: '26', x: -162.5922, y: -2.4118, rssi: {'romeoE': null, 'juliaE': -77, 'mainEntrance': null, 'juliaC': -81, 'juliaE2': -86, 'juliaF': -85, 'romeoB': null}),
    SurveyPoint(id: '27', x: -159.8234, y: -1.4781, rssi: {'romeoE': null, 'juliaE': -69, 'mainEntrance': null, 'juliaC': -75, 'juliaE2': -83, 'juliaF': -83, 'romeoB': null}),
    SurveyPoint(id: '28', x: -159.8234, y: 1.5991, rssi: {'romeoE': null, 'juliaE': -73, 'mainEntrance': null, 'juliaC': -83, 'juliaE2': -87, 'juliaF': -87, 'romeoB': null}),
  ];

  final BeaconScanner _beaconScanner = BeaconScanner();
  final Map<String, double> _liveRssi = {};
  final Map<String, List<int>> _beaconRssiWindows = {};
  final Map<String, DateTime> _lastUpdatedTime = {};
  late FingerprintLocator _locator;
  Timer? _rssiDecayTimer;
  bool _isSimulatingBle = false;
  Timer? _simulationTimer;
  int _simulationIndex = 0;

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

    _locator = FingerprintLocator(surveyPoints: _surveyDataPoints, k: 3);

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
      
      _initBeaconScanning();
    });
  }

  @override
  void dispose() {
    _beaconScanner.stopScan();
    _rssiDecayTimer?.cancel();
    _simulationTimer?.cancel();
    _mapAnimationController.dispose();
    _transformController.dispose();
    _startXCtrl.dispose();
    _startYCtrl.dispose();
    _endXCtrl.dispose();
    _endYCtrl.dispose();
    super.dispose();
  }

  /// BEHAVIORAL MECHANISM:
  /// Starts real Bluetooth Beacon scanning if simulated mode is not active. Updates beacon RSSI sliding window
  /// and triggers location update. Cleans up stale beacon readings that are older than 5 seconds.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _initBeaconScanning() {
    try {
      _beaconScanner.startScan(
        onBeaconFound: (beaconId, rssi) {
          if (!mounted) return;
          if (_isSimulatingBle) return;

          // Update sliding window (size 5)
          final window = _beaconRssiWindows.putIfAbsent(beaconId, () => []);
          window.add(rssi);
          if (window.length > 5) {
            window.removeAt(0);
          }

          // Compute window average
          final avgRssi = window.reduce((a, b) => a + b) / window.length;

          setState(() {
            _liveRssi[beaconId] = avgRssi;
            _lastUpdatedTime[beaconId] = DateTime.now();
            _updateUserLocationFromRssi();
          });
        },
      ).then((success) {
        if (!success) {
          debugPrint('BLE Scan could not start: check permissions or Bluetooth state.');
        }
      });
    } catch (e) {
      debugPrint('Error starting BLE Scan: $e');
    }

    // Periodically decay/remove stale beacon RSSI values (5 seconds timeout)
    _rssiDecayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      bool changed = false;

      _lastUpdatedTime.removeWhere((id, time) {
        if (now.difference(time).inSeconds > 5) {
          _liveRssi.remove(id);
          _beaconRssiWindows.remove(id); // Clear window as well
          changed = true;
          return true;
        }
        return false;
      });

      if (changed) {
        setState(() {
          _updateUserLocationFromRssi();
        });
      }
    });
  }

  /// BEHAVIORAL MECHANISM:
  /// Passes the averaged beacon RSSI data to the FingerprintLocator. It uses weighted KNN to interpolate
  /// user's coordinate. If an active destination exists, it recalculates the A* navigation path.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _updateUserLocationFromRssi() {
    if (_liveRssi.isEmpty) return;

    final result = _locator.locate(_liveRssi);
    if (result != null) {
      _startMarker = MapPoint(result.x, result.y);
      _startXCtrl.text = result.x.toStringAsFixed(2);
      _startYCtrl.text = result.y.toStringAsFixed(2);

      // If there is an active destination, automatically recalculate path
      final endX = double.tryParse(_endXCtrl.text);
      final endY = double.tryParse(_endYCtrl.text);
      if (endX != null && endY != null) {
        final startNode = _nearestNode(result.x, result.y);
        final endNode = _nearestNode(endX, endY);
        final routeResult = AStarAlgorithm().findPath(startNode, endNode);
        if (routeResult.isNotEmpty) {
          _computedPath = routeResult.map((n) => MapPoint(n.x, n.y)).toList();
        }
      }
    }
  }

  /// BEHAVIORAL MECHANISM:
  /// Loops through the 28 survey points sequentially every second, feeding their hardcoded RSSI values into the locator,
  /// simulating user movements along nodes.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _runBleSimulation() {
    _simulationTimer?.cancel();
    _simulationIndex = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (!_isSimulatingBle) {
        timer.cancel();
        return;
      }

      final currentPoint = _surveyDataPoints[_simulationIndex];

      setState(() {
        _liveRssi.clear();
        currentPoint.rssi.forEach((key, val) {
          if (val != null) {
            _liveRssi[key] = val.toDouble();
          }
        });

        // Estimate coordinates
        _updateUserLocationFromRssi();

        // Update status message for user visibility
        _statusMsg = 'Sim: Node ${currentPoint.id} (${_simulationIndex + 1}/28)';
      });

      _simulationIndex++;
      if (_simulationIndex >= _surveyDataPoints.length) {
        _simulationIndex = 0; // Loop back
      }
    });
  }

  /// BEHAVIORAL MECHANISM:
  /// Queries mock plants service, simulating network request delay before returning plants lists.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Future<void>
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

  /// BEHAVIORAL MECHANISM:
  /// Iterates over all graph nodes to find the node closest in Euclidean distance to target coordinates.
  ///
  /// PARAMETERS:
  /// - x (double): Target X coordinate.
  /// - y (double): Target Y coordinate.
  ///
  /// RETURNS:
  /// - PathNode: The nearest node object found.
  PathNode _nearestNode(double x, double y) {
    PathNode? best;
    double bestDist = double.infinity;
    for (final node in _pathNodes) {
      final dx = node.x - x;
      final dy = node.y - y;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = node;
      }
    }
    return best!;
  }

  /// BEHAVIORAL MECHANISM:
  /// Triggers A* pathfinding calculation from start coordinates to end coordinates.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
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

  /// BEHAVIORAL MECHANISM:
  /// Transforms a CAD map coordinate to a local pixel coordinate inside the screen viewport.
  ///
  /// PARAMETERS:
  /// - point (MapPoint): Mapped CAD coordinates.
  /// - widgetSize (Size): Viewport dimensions.
  ///
  /// RETURNS:
  /// - Offset: Mapped screen pixel offset.
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

  /// BEHAVIORAL MECHANISM:
  /// Performs inverse transformation mapping local screen pixel offset back to CAD coordinates.
  ///
  /// PARAMETERS:
  /// - pixel (Offset): Screen pixel offset.
  /// - widgetSize (Size): Viewport dimensions.
  ///
  /// RETURNS:
  /// - MapPoint: Mapped CAD coordinate.
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

  /// BEHAVIORAL MECHANISM:
  /// Handles map touch down events. Toggles position popup, coordinate updates, or location update confirm dialogs.
  ///
  /// PARAMETERS:
  /// - details (TapDownDetails): Gesture details.
  /// - widgetSize (Size): Screen viewport size.
  ///
  /// RETURNS:
  /// - Void.
  void _onMapTap(TapDownDetails details, Size widgetSize) {
    final RenderBox? box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPos = box.globalToLocal(details.globalPosition);
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformed = MatrixUtils.transformPoint(inverseMatrix, localPos);

    final cad = pixelToCad(transformed, widgetSize);

    if (_editingPlant != null) {
      setState(() {
        _tempEditPoint = cad;
        _tappedPixel = details.localPosition;
        _showConfirmEditPopup = true;
        _showTapPopup = false;
      });
      return;
    }

    setState(() {
      _tappedPoint = cad;
      _tappedPixel = details.localPosition;
      _showTapPopup = true;
      _selectedPlant = null;
    });
  }

  /// BEHAVIORAL MECHANISM:
  /// Dismisses coordinate selection popup.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _dismissPopup() {
    setState(() => _showTapPopup = false);
  }

  /// BEHAVIORAL MECHANISM:
  /// Sets coordinate selected by user tap as start location.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _setAsStart() {
    if (_tappedPoint == null) return;
    setState(() {
      _startXCtrl.text = _tappedPoint!.x.toStringAsFixed(2);
      _startYCtrl.text = _tappedPoint!.y.toStringAsFixed(2);
      _showTapPopup = false;
      _showInputPanel = true;
    });
  }

  /// BEHAVIORAL MECHANISM:
  /// Sets coordinate selected by user tap as destination.
  ///
  /// PARAMETERS:
  /// None.
  ///
  /// RETURNS:
  /// - Void.
  void _setAsDestination() {
    if (_tappedPoint == null) return;
    setState(() {
      _endXCtrl.text = _tappedPoint!.x.toStringAsFixed(2);
      _endYCtrl.text = _tappedPoint!.y.toStringAsFixed(2);
      _showTapPopup = false;
      _showInputPanel = true;
    });
  }

  /// BEHAVIORAL MECHANISM:
  /// Centers the interactive map viewer viewport on target plant coordinates with smooth scaling animation.
  ///
  /// PARAMETERS:
  /// - plant (MockPlantInfo): The target plant to focus on.
  /// - widgetSize (Size): Viewport dimensions.
  ///
  /// RETURNS:
  /// - Void.
  void _centerOnPlant(MockPlantInfo plant, Size widgetSize) {
    final targetPixel = cadToPixel(
      point: MapPoint(plant.coordinateX, plant.coordinateY),
      widgetSize: widgetSize,
    );

    const zoomScale = 2.5;
    final dx = widgetSize.width / 2 - targetPixel.dx * zoomScale;
    final dy = widgetSize.height / 2 - targetPixel.dy * zoomScale;

    final targetMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(zoomScale, zoomScale, 1.0);

    final startMatrix = _transformController.value;
    _mapMatrixAnimation = Matrix4Tween(
      begin: startMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _mapAnimationController,
      curve: Curves.fastOutSlowIn,
    ));

    _mapAnimationController.forward(from: 0.0);
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
                margin: const EdgeInsets.only(right: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  _statusMsg,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: _isLoadingPlants
                ? const SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.local_florist_outlined),
            tooltip: 'Discover Plants',
            onPressed: _isLoadingPlants ? null : _fetchPlants,
          ),
          IconButton(
            icon: Icon(
              _isSimulatingBle ? Icons.pause_circle_filled : Icons.play_circle_outline,
              color: _isSimulatingBle ? const Color(0xFFEF5350) : Colors.white,
            ),
            tooltip: _isSimulatingBle ? 'Stop Simulation' : 'Simulate BLE',
            onPressed: () {
              setState(() {
                _isSimulatingBle = !_isSimulatingBle;
                if (_isSimulatingBle) {
                  _beaconScanner.stopScan();
                  _rssiDecayTimer?.cancel();
                  _liveRssi.clear();
                  _beaconRssiWindows.clear();
                  _runBleSimulation();
                } else {
                  _simulationTimer?.cancel();
                  _initBeaconScanning();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              _showInputPanel ? Icons.close : Icons.search,
              color: _showInputPanel ? const Color(0xFFEF5350) : Colors.white,
            ),
            tooltip: _showInputPanel ? 'Close' : 'Find Route',
            onPressed: () => setState(() {
              _showInputPanel = !_showInputPanel;
              _showTapPopup = false;
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
                  key: _mapKey,
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 50.0,
                  boundaryMargin: const EdgeInsets.all(100.0),
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
                      if (widget.graphNodes != null && widget.graphEdges != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: GraphPainter(
                              nodes: widget.graphNodes!,
                              edges: widget.graphEdges!,
                              widgetSize: widgetSize,
                              cadToPixel: (p) => cadToPixel(point: p, widgetSize: widgetSize),
                            ),
                          ),
                        ),
                      if (_computedPath.length >= 2)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PathPainter(
                              path: _computedPath,
                              widgetSize: widgetSize,
                              cadToPixel: (p) => cadToPixel(point: p, widgetSize: widgetSize),
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
                          child: const UserMarker(),
                        ),
                      if (_endMarker != null && _selectedPlant == null)
                        _buildMarker(
                          point: _endMarker!,
                          widgetSize: widgetSize,
                          width: 20.0,
                          height: 20.0,
                          anchorX: 0.5,
                          anchorY: 1.0,
                          child: const DestinationMarker(),
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
                                      blurRadius: 3.0,
                                      offset: Offset(0.0, 1.0),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(1.0),
                                child: const Icon(
                                  Icons.local_florist,
                                  color: Color(0xFF2E7D32),
                                  size: 5.0,
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
                                    blurRadius: 2.0,
                                    offset: Offset(0.0, 1.0),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(1.0),
                              child: const Icon(
                                Icons.place,
                                color: Color(0xFFEF5350),
                                size: 5.0,
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
                TapPopup(
                  tappedPoint: _tappedPoint,
                  tappedPixel: _tappedPixel,
                  widgetSize: widgetSize,
                  onDismiss: _dismissPopup,
                  onSetAsStart: _setAsStart,
                  onSetAsDestination: _setAsDestination,
                ),

              // ── Confirm Edit Popup ────────────────────────
              if (_showConfirmEditPopup && _tappedPixel != null && _tempEditPoint != null && _editingPlant != null)
                ConfirmEditPopup(
                  tempEditPoint: _tempEditPoint,
                  editingPlant: _editingPlant,
                  cadToPixel: (p) => cadToPixel(point: p, widgetSize: widgetSize),
                  widgetSize: widgetSize,
                  onConfirm: () {
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
                  onCancel: () {
                    setState(() {
                      _editingPlant = null;
                      _tempEditPoint = null;
                      _showConfirmEditPopup = false;
                    });
                  },
                ),

              // ── Input Panel ───────────────────────────────
              AnimatedSlide(
                offset: _showInputPanel ? Offset.zero : const Offset(0.0, -1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _showInputPanel ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: InputPanel(
                    startXCtrl: _startXCtrl,
                    startYCtrl: _startYCtrl,
                    endXCtrl: _endXCtrl,
                    endYCtrl: _endYCtrl,
                    statusMsg: _statusMsg,
                    computedPath: _computedPath,
                    onFindRoute: _runAStar,
                  ),
                ),
              ),

              // ── Discovered Plants List Panel ─────────────────────────────
              Positioned(
                bottom: 16.0,
                left: 16.0,
                right: 16.0,
                child: AnimatedSlide(
                  offset: _discoveredPlants.isNotEmpty ? Offset.zero : const Offset(0.0, 1.5),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _discoveredPlants.isNotEmpty ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: PlantsListPanel(
                      discoveredPlants: _discoveredPlants,
                      selectedPlant: _selectedPlant,
                      editingPlant: _editingPlant,
                      widgetSize: widgetSize,
                      onPlantTap: (plant) {
                        if (_editingPlant != null) return;
                        setState(() {
                          _selectedPlant = plant;
                          _endXCtrl.text = plant.coordinateX.toStringAsFixed(2);
                          _endYCtrl.text = plant.coordinateY.toStringAsFixed(2);
                          _runAStar();
                        });
                        _centerOnPlant(plant, widgetSize);
                      },
                      onEditToggle: (plant) {
                        setState(() {
                          if (_editingPlant?.plantId == plant.plantId) {
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
                      onClose: () {
                        setState(() {
                          _discoveredPlants = [];
                          _selectedPlant = null;
                          _editingPlant = null;
                          _tempEditPoint = null;
                          _showConfirmEditPopup = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: InfoBar(
        startMarker: _startMarker,
        endMarker: _endMarker,
        userPosition: widget.userPosition,
        destination: widget.destination,
        liveRssiCount: _liveRssi.length,
        computedPathLength: _computedPath.length,
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
}
