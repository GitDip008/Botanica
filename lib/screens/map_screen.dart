import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../data/garden_sections.dart';
import '../services/language_service.dart';
import '../services/routing_service.dart';
import '../services/usage_tracking_service.dart';
import '../widgets/app_drawer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? _userLocation;
  GardenSection? _selected;
  final MapController _mapController = MapController();
  bool _locating = false;
  final _searchCtrl = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _query = '';
  List<LatLng> _routePoints = const [];
  bool _routing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GardenSection> get _matches {
    if (_query.trim().isEmpty) return const [];
    final q = _query.toLowerCase();
    return gardenSections
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.blooms.toLowerCase().contains(q))
        .toList();
  }

  void _selectSection(GardenSection s) {
    setState(() {
      _selected = s;
      _query = '';
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
    _mapController.move(s.location, 18);
  }

  /// Draws an in-app walking route from the user's location to the section.
  /// Falls back to external Google Maps if routing isn't available.
  Future<void> _openDirections(GardenSection s) async {
    // Need the user's location to route from
    if (_userLocation == null) {
      await _startTracking();
      if (_userLocation == null) {
        _launchExternal(s); // can't get GPS — hand off to Google Maps
        return;
      }
    }

    setState(() => _routing = true);
    final route =
        await RoutingService.instance.walkingRoute(_userLocation!, s.location);
    if (!mounted) return;

    if (route != null && route.length > 1) {
      setState(() {
        _routePoints = route;
        _routing = false;
      });
      // Fit the map to show both endpoints
      _mapController.move(
        LatLng(
          (_userLocation!.latitude + s.location.latitude) / 2,
          (_userLocation!.longitude + s.location.longitude) / 2,
        ),
        17.5,
      );
    } else {
      // Routing unavailable (no key / no coverage) — external fallback
      setState(() => _routing = false);
      _launchExternal(s);
    }
  }

  Future<void> _launchExternal(GardenSection s) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${s.location.latitude},${s.location.longitude}'
      '&travelmode=walking',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _clearRoute() => setState(() => _routePoints = const []);

  @override
  void initState() {
    super.initState();
    _startTracking();
    UsageTrackingService.instance.log(UsageTrackingService.featureMap);
  }

  Future<void> _startTracking() async {
    setState(() => _locating = true);
    final status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() => _locating = false);
      return;
    }

    // One-shot first fix
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() { _userLocation = LatLng(pos.latitude, pos.longitude); _locating = false; });
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }

    // Then stream updates
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      if (mounted) setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
    });
  }

  String _distanceText(GardenSection section) {
    if (_userLocation == null) return '📍 Tap for info';
    final dist = const Distance().as(LengthUnit.Meter, _userLocation!, section.location);
    if (dist < 15) return '✅ You are here!';
    if (dist < 50) return '🟢 ${dist.toInt()}m — very close';
    if (dist < 200) return '🟡 ${dist.toInt()}m — keep walking';
    return '🔴 ${dist.toInt()}m away';
  }

  bool _isNearby(GardenSection section) {
    if (_userLocation == null) return false;
    return const Distance().as(LengthUnit.Meter, _userLocation!, section.location) < 15;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(onSelectTab: (i) {
        Navigator.popUntil(context, (r) => r.isFirst);
      }),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: gardenCenter,
              initialZoom: 17.5,
              minZoom: 14,
              maxZoom: 20,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              // OpenStreetMap tiles — completely free, no API key
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.botanica_ar',
              ),

              // Walking route polyline
              if (_routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: const Color(0xFF2E7D32),
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Section markers
              MarkerLayer(
                markers: [
                  ...gardenSections.map((s) => Marker(
                    point: s.location,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selected = s);
                        _mapController.move(s.location, 18);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _isNearby(s) ? s.color : s.color.withOpacity(0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selected?.id == s.id
                                ? Colors.white
                                : _isNearby(s)
                                    ? Colors.greenAccent
                                    : Colors.white70,
                            width: _selected?.id == s.id ? 3 : 2,
                          ),
                          boxShadow: _isNearby(s)
                              ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.6), blurRadius: 10, spreadRadius: 3)]
                              : null,
                        ),
                        child: Center(
                          child: Text(s.emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                  )),

                  // User GPS blue dot
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, spreadRadius: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top: menu button + search field + results dropdown
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Menu button
                      Material(
                        color: const Color(0xFF1A2E1E),
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          icon: const Icon(Icons.menu_rounded,
                              color: Color(0xFFE8F5E9)),
                          onPressed: () =>
                              _scaffoldKey.currentState?.openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Search field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2E1E).withValues(alpha: 0.97),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF2E7D32)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search,
                                  color: Color(0xFF66BB6A), size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() => _query = v),
                                  style: const TextStyle(
                                      color: Color(0xFFE8F5E9), fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: s.searchSectionHint,
                                    hintStyle: const TextStyle(
                                        color: Color(0xFF4A7A50), fontSize: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              if (_locating)
                                const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF66BB6A),
                                          strokeWidth: 2)),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    _userLocation != null
                                        ? Icons.gps_fixed
                                        : Icons.gps_off,
                                    color: _userLocation != null
                                        ? Colors.greenAccent
                                        : Colors.orange,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search results dropdown
                  if (_matches.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6, left: 56),
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111F16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2E7D32)),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: _matches
                            .map((sec) => ListTile(
                                  dense: true,
                                  leading: Text(sec.emoji,
                                      style: const TextStyle(fontSize: 20)),
                                  title: Text(sec.name,
                                      style: const TextStyle(
                                          color: Color(0xFFE8F5E9),
                                          fontSize: 14)),
                                  subtitle: Text(sec.blooms,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFF81C784),
                                          fontSize: 11)),
                                  onTap: () => _selectSection(sec),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Re-center button
          Positioned(
            right: 12,
            bottom: _selected != null ? 210 : 30,
            child: FloatingActionButton.small(
              backgroundColor: const Color(0xFF1A2E1E),
              onPressed: () {
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 18);
                } else {
                  _mapController.move(gardenCenter, 17.5);
                }
              },
              child: const Icon(Icons.my_location, color: Color(0xFF66BB6A)),
            ),
          ),

          // Section info card
          if (_selected != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(child: Container(width: 40, height: 4,
                        decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Text(_selected!.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selected!.name,
                                  style: const TextStyle(color: Color(0xFFE8F5E9),
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(_distanceText(_selected!),
                                  style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 12)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _selected = null),
                          child: const Icon(Icons.close, color: Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(_selected!.description,
                        style: const TextStyle(color: Color(0xFFE8F5E9), fontSize: 13, height: 1.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.local_florist, color: Color(0xFF66BB6A), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${s.nowLabel}: ${_selected!.blooms}',
                              style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Directions / Clear route
                    SizedBox(
                      width: double.infinity,
                      child: _routePoints.isNotEmpty
                          ? OutlinedButton.icon(
                              onPressed: _clearRoute,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: Text(s.clearRoute),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF9A9A),
                                side: const BorderSide(color: Color(0xFF8C2336)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _routing
                                  ? null
                                  : () => _openDirections(_selected!),
                              icon: _routing
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.directions_walk_rounded,
                                      size: 18),
                              label: Text(_routing ? s.findingRoute : s.directions),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
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
