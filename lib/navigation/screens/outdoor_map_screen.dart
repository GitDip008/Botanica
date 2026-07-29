// lib/navigation/screens/outdoor_map_screen.dart
//
// Browse map — shows all outdoor plants as markers on flutter_map (OSM).
// No active navigation. Tapping a marker selects it; "Go" starts navigation.
//
// Ported from Google Maps to flutter_map so the app needs no Maps API key /
// billing and stays consistent with the rest of Botanica.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';
import '../providers/navigation_provider.dart';
import 'outdoor_navigation_screen.dart';

/// Oulu Botanical Garden — default map centre.
const LatLng _gardenCentre = LatLng(65.0638, 25.4638);

class OutdoorMapScreen extends ConsumerStatefulWidget {
  const OutdoorMapScreen({super.key});

  @override
  ConsumerState<OutdoorMapScreen> createState() => _OutdoorMapScreenState();
}

class _OutdoorMapScreenState extends ConsumerState<OutdoorMapScreen> {
  final MapController _mapController = MapController();
  Plant? _selectedPlant;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);
    final gpsAsync    = ref.watch(gpsPositionProvider);

    final userPos = gpsAsync.whenOrNull(
      data: (p) => LatLng(p.latitude, p.longitude),
    );

    // Build markers for all outdoor plants that have GPS coordinates.
    final markers = <Marker>[];
    int unmapped = 0;

    plantsAsync.whenOrNull(data: (plants) {
      final outdoor = plants.where((p) => !p.isIndoor).toList();
      for (final p in outdoor) {
        if (!p.hasGpsCoords) { unmapped++; continue; }
        final isSelected = _selectedPlant?.id == p.id;
        markers.add(Marker(
          point: LatLng(p.gpsLat!, p.gpsLng!),
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => setState(() => _selectedPlant = p),
            child: Icon(
              Icons.location_on,
              size: isSelected ? 44 : 36,
              color: isSelected
                  ? Colors.lightGreenAccent
                  : Colors.cyanAccent,
              shadows: const [
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
          ),
        ));
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _gardenCentre,
              initialZoom: 17,
              onTap: (_, __) => setState(() => _selectedPlant = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.botanica.ar',
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
              MarkerLayer(markers: markers),
            ],
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E1A).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.lightGreenAccent.withOpacity(0.3)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white70),
                      onPressed: () => Navigator.maybePop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.park_outlined,
                        color: Colors.lightGreenAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Outdoor Plant Map',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ),
                    // Plant count chip
                    plantsAsync.whenOrNull(
                      data: (plants) {
                        final mapped = plants
                            .where((p) => !p.isIndoor && p.hasGpsCoords)
                            .length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.lightGreenAccent
                                    .withOpacity(0.4)),
                          ),
                          child: Text(
                            '$mapped plants',
                            style: const TextStyle(
                                color: Colors.lightGreenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ) ?? const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),

          // ── Unmapped warning ──────────────────────────────────────────────
          if (unmapped > 0)
            Positioned(
              top: 80, left: 0, right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Text(
                      '$unmapped plant${unmapped == 1 ? '' : 's'} not yet mapped',
                      style: const TextStyle(
                          color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),

          // ── Selected plant card ───────────────────────────────────────────
          if (_selectedPlant != null)
            Positioned(
              bottom: 24, left: 16, right: 16,
              child: _PlantCard(
                plant: _selectedPlant!,
                onNavigate: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OutdoorNavigationScreen(
                        plantId: _selectedPlant!.id),
                  ),
                ),
                onDismiss: () => setState(() => _selectedPlant = null),
              ),
            ),

          // ── My location button ────────────────────────────────────────────
          Positioned(
            bottom: _selectedPlant != null ? 160 : 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: const Color(0xFF1A2E1A),
              foregroundColor: Colors.lightGreenAccent,
              onPressed: () {
                if (userPos != null) {
                  _mapController.move(userPos, 18);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Loading state ─────────────────────────────────────────────────
          if (plantsAsync.isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.lightGreenAccent),
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
// Selected plant card
// ─────────────────────────────────────────────────────────────────────────────

class _PlantCard extends StatelessWidget {
  const _PlantCard({
    required this.plant,
    required this.onNavigate,
    required this.onDismiss,
  });
  final Plant plant;
  final VoidCallback onNavigate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A2E1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.lightGreenAccent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Plant image or icon
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: plant.displayImageUrl != null
                  ? Image.network(
                      plant.displayImageUrl!,
                      width: 80, height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconBox(),
                    )
                  : _iconBox(),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.name,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (plant.family != null) ...[
                          Text(plant.family!,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                          const Text(' · ',
                              style: TextStyle(color: Colors.white24)),
                        ],
                        Text('Section ${plant.section}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.near_me, size: 14),
                    label: const Text('Go', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.lightGreenAccent,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox() => Container(
        width: 80, height: 80,
        color: Colors.lightGreenAccent.withOpacity(0.1),
        child: const Icon(Icons.park_outlined,
            color: Colors.lightGreenAccent, size: 32),
      );
}
