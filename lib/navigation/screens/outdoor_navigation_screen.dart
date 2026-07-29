// lib/navigation/screens/outdoor_navigation_screen.dart
//
// Outdoor navigation: flutter_map (OSM dark tiles) with plant markers, a top
// banner (plant name + live distance/hint), and a rotating arrow toward the
// target. Bearing/distance/arrival are computed on-device (navigation_provider).
// Auto-routes to ArrivalScreen on arrival.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/plant.dart';
import '../nav_routes.dart';
import '../providers/navigation_provider.dart';
import '../providers/plant_provider.dart';
import 'arrival_screen.dart';

/// Oulu Botanical Garden — default map centre.
const LatLng _gardenCentre = LatLng(65.0638, 25.4638);

class OutdoorNavigationScreen extends ConsumerStatefulWidget {
  const OutdoorNavigationScreen({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<OutdoorNavigationScreen> createState() =>
      _OutdoorNavigationScreenState();
}

class _OutdoorNavigationScreenState
    extends ConsumerState<OutdoorNavigationScreen> {
  final MapController _mapController = MapController();
  bool _followUser = true; // auto-pan to user; disabled on manual drag
  bool _mapReady = false;
  double _zoom = 17;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _animateTo(LatLng pos) {
    if (!_followUser || !_mapReady) return;
    _mapController.move(pos, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(plantByIdProvider(widget.plantId));
    final plantsAsync = ref.watch(plantsProvider);
    final navAsync = ref.watch(navigationStateProvider(widget.plantId));
    final arrowAngle = ref.watch(arrowAngleProvider(widget.plantId));
    final gpsAsync = ref.watch(gpsPositionProvider);

    // Arrival listener
    ref.listen(navigationStateProvider(widget.plantId), (_, next) {
      next.whenData((s) {
        if (s.arrived && mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => ArrivalScreen(plantId: widget.plantId),
          ));
        }
      });
    });

    // Auto-pan to user
    ref.listen(gpsPositionProvider, (_, next) {
      next.whenData((pos) => _animateTo(LatLng(pos.latitude, pos.longitude)));
    });

    final userPos = gpsAsync.whenOrNull(
      data: (p) => LatLng(p.latitude, p.longitude),
    );

    // Show "no coordinates" screen if plant exists but has no GPS
    if (plant != null && !plant.isIndoor && !plant.hasGpsCoords) {
      return _NoCoordinatesScreen(plant: plant);
    }

    // Collect all outdoor mapped plants for markers
    final allOutdoorMarkers = <Marker>[];
    plantsAsync.whenOrNull(data: (plants) {
      for (final p in plants.where((p) => !p.isIndoor && p.hasGpsCoords)) {
        final isTarget = p.id == widget.plantId;
        allOutdoorMarkers.add(Marker(
          point: LatLng(p.gpsLat!, p.gpsLng!),
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: isTarget
                ? null
                : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            OutdoorNavigationScreen(plantId: p.id),
                      ),
                    ),
            child: Icon(
              Icons.location_on,
              size: isTarget ? 44 : 34,
              color: isTarget ? Colors.greenAccent : Colors.cyanAccent,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
        ));
      }
    });

    final initialTarget = userPos ??
        (plant?.hasGpsCoords == true
            ? LatLng(plant!.gpsLat!, plant.gpsLng!)
            : _gardenCentre);

    final distance = navAsync.whenOrNull(data: (s) => s.distanceMetres);
    final hint = navAsync.whenOrNull(data: (s) => s.hint);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialTarget,
              initialZoom: 17,
              onMapReady: () => _mapReady = true,
              onPositionChanged: (camera, hasGesture) {
                _zoom = camera.zoom;
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: kNavTileUrl,
                userAgentPackageName: kNavTileUserAgent,
              ),
              if (userPos != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userPos,
                      width: 22,
                      height: 22,
                      child: const _UserDot(),
                    ),
                  ],
                ),
              MarkerLayer(markers: allOutdoorMarkers),
            ],
          ),

          // ── Top banner ─────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: _TopBanner(
                plant: plant,
                hint: hint,
                distance: distance,
                onBack: () => backToPlantList(context),
              ),
            ),
          ),

          // ── Re-centre button (shown when user has panned away) ─────────────
          if (!_followUser)
            Positioned(
              bottom: 40,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recentre',
                backgroundColor: const Color(0xFF1A2E1A),
                foregroundColor: Colors.greenAccent,
                onPressed: () {
                  setState(() => _followUser = true);
                  if (userPos != null && _mapReady) {
                    _mapController.move(userPos, 17);
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ),

          // ── Navigation arrow ───────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 16,
            child: _ArrowIndicator(angleDegrees: arrowAngle),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User location dot (flutter_map has no built-in blue dot)
// ─────────────────────────────────────────────────────────────────────────────

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No coordinates screen
// ─────────────────────────────────────────────────────────────────────────────

class _NoCoordinatesScreen extends StatelessWidget {
  const _NoCoordinatesScreen({required this.plant});
  final Plant plant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withOpacity(0.1),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: const Icon(Icons.location_off,
                    color: Colors.amber, size: 42),
              ),
              const SizedBox(height: 24),
              Text(
                plant.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                plant.name,
                style: const TextStyle(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                    fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Text(
                  'This plant hasn\'t been mapped yet.\n\n'
                  'A staff member needs to assign GPS coordinates to this '
                  'plant before outdoor navigation can guide you to it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      height: 1.6),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => backToPlantList(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to plant list'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top banner
// ─────────────────────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  const _TopBanner({
    required this.plant,
    required this.hint,
    required this.distance,
    required this.onBack,
  });

  final Plant? plant;
  final String? hint;
  final double? distance;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
            blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.park_outlined, color: Colors.greenAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant?.displayName ?? '…',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hint ?? 'Head toward the marker',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          if (distance != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Text(
                distance! >= 1000
                    ? '${(distance! / 1000).toStringAsFixed(1)} km'
                    : '${distance!.toStringAsFixed(0)} m',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation arrow
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowIndicator extends StatelessWidget {
  const _ArrowIndicator({required this.angleDegrees});
  final double angleDegrees;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A2E1A).withOpacity(0.92),
        border: Border.all(
            color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.greenAccent.withOpacity(0.15),
            blurRadius: 10, spreadRadius: 2)],
      ),
      child: Transform.rotate(
        angle: angleDegrees * 3.14159265 / 180,
        child: const Icon(Icons.navigation,
            color: Colors.greenAccent, size: 30),
      ),
    );
  }
}
