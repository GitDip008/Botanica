// lib/navigation/screens/plant_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/plant_index.dart';
import '../../widgets/plant_tags_bar.dart';
import '../models/plant.dart';
import '../providers/plant_provider.dart';
import 'greenhouse_map_screen.dart';
import 'outdoor_map_screen.dart';
import 'outdoor_navigation_screen.dart';

class PlantListScreen extends ConsumerStatefulWidget {
  const PlantListScreen({super.key});

  @override
  ConsumerState<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends ConsumerState<PlantListScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Empty query -> highlighted (tagged) plants. Otherwise filter the full
  /// index by name / Finnish name / section (capped so the list stays snappy).
  List<Plant> _filter(List<Plant> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      final hi = all
          .where((p) =>
              PlantIndex.instance.factsFor(p.name)?.tags.isNotEmpty ?? false)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      return hi;
    }
    final res = all
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            (p.finnishName?.toLowerCase().contains(q) ?? false) ||
            p.section.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return res.length > 300 ? res.sublist(0, 300) : res;
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1A0D),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeroHeader()),
          SliverToBoxAdapter(
            child: _SearchBar(
              controller: _ctrl,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          plantsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Colors.greenAccent),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(plantsProvider),
              ),
            ),
            data: (all) {
              final list = _filter(all);
              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No plants found.'
                          : 'No matches for "$_query"',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          _query.isEmpty
                              ? 'Highlighted plants (${list.length})'
                              : '${list.length} result${list.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return _PlantTile(plant: list[i - 1]);
                  },
                  childCount: list.length + 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search 11,000+ plants by name or section…',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: const Color(0xFF1A2E1A),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header — logo + welcome message
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B0D), Color(0xFF1A3D1A), Color(0xFF0D2420)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Logo mark ────────────────────────────────────────────────────
              Row(
                children: [
                  _LogoMark(),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Garden Guide',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        'Find & Navigate to Plants',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Welcome message ───────────────────────────────────────────────
              const Text(
                'Welcome to the garden.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explore thousands of species at your own pace. '
                'Tap any plant below and we\'ll guide you straight to it — '
                'outdoors on the map, or deep inside the greenhouse.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 24),

              // ── Greenhouse map button ─────────────────────────────────────────
              _GreenhouseMapButton(),

              const SizedBox(height: 10),

              // ── Outdoor map button ────────────────────────────────────────────
              _OutdoorMapButton(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo mark — leaf drawn with Canvas
// ─────────────────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF00BFA5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(painter: _LeafPainter()),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    // Draw a stylised leaf shape
    final path = Path();
    path.moveTo(cx, cy - 16);
    path.cubicTo(cx + 14, cy - 10, cx + 14, cy + 8, cx, cy + 16);
    path.cubicTo(cx - 14, cy + 8, cx - 14, cy - 10, cx, cy - 16);
    canvas.drawPath(path, paint);

    // Centre vein
    final veinPaint = Paint()
      ..color = const Color(0xFF2E7D32).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 13), Offset(cx, cy + 14), veinPaint);

    // Side veins
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx + 8, cy + 2), veinPaint);
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx - 8, cy + 2), veinPaint);
    canvas.drawLine(Offset(cx, cy + 4), Offset(cx + 7, cy + 9), veinPaint);
    canvas.drawLine(Offset(cx, cy + 4), Offset(cx - 7, cy + 9), veinPaint);
  }

  @override
  bool shouldRepaint(_LeafPainter _) => false;
}

class _GreenhouseMapButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GreenhouseMapScreen()),
        ),
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('View Greenhouse Floor Plan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.greenAccent,
          side: const BorderSide(color: Colors.greenAccent, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }
}

class _OutdoorMapButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OutdoorMapScreen()),
        ),
        icon: const Icon(Icons.park_outlined, size: 18),
        label: const Text('View Outdoor Plant Map'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.lightGreenAccent,
          side: const BorderSide(
              color: Colors.lightGreenAccent, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
      ),
    );
  }
}

class _PlantTile extends StatelessWidget {
  const _PlantTile({required this.plant});
  final Plant plant;

  void _navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => plant.isIndoor
            ? GreenhouseMapScreen(plantId: plant.id)
            : OutdoorNavigationScreen(plantId: plant.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: const Color(0xFF1A2E1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _PlantAvatar(plant: plant, size: 48),
        title: Text(
          plant.displayName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plant.name,
              style: const TextStyle(
                color: Colors.white60,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  'Section ${plant.section}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (plant.family != null) ...[
                  const Text(' · ',
                      style: TextStyle(color: Colors.white24, fontSize: 11)),
                  Text(
                    plant.family!,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
                if (plant.placementStatus != null &&
                    plant.placementStatus != 'Healthy') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plant.placementStatus!,
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
            // Curated tags (hover buttons) for highlighted plants.
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: PlantTagsBar(scientificName: plant.name),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: () => _navigate(context),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared plant avatar — image if available, icon fallback if not
// ─────────────────────────────────────────────────────────────────────────────

class _PlantAvatar extends StatelessWidget {
  const _PlantAvatar({required this.plant, this.size = 48});
  final Plant plant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = plant.displayImageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconFallback(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : _iconFallback(),
        ),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() => CircleAvatar(
        radius: size / 2,
        backgroundColor: plant.isIndoor
            ? Colors.teal.withOpacity(0.2)
            : Colors.green.withOpacity(0.2),
        child: Icon(
          plant.isIndoor ? Icons.home_work_outlined : Icons.park_outlined,
          color: plant.isIndoor ? Colors.tealAccent : Colors.greenAccent,
          size: size * 0.45,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Could not load plants',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
