// lib/widgets/cell_picker_sheet.dart
//
// Tap-to-locate for the greenhouses: pick one of the 37 surveyed planting cells
// as either "I am here" or "take me here".
//
// This is the indoor positioning method docs/navigation_graph.md chose over
// beacons — the visitor tells us where they are by tapping a cell, so no
// hardware, no fingerprinting and no calibration is involved. It works today,
// with the beacon path (lib/services/beacons_service.dart) still available for
// automatic positioning once hardware is installed.
//
// ponytail: a modal sheet over a searchable list, no state management library.
// 37 items is a list, not an architecture.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../data/greenhouse_cells.dart';

// Re-exported so a caller needs only this one import to use the picker AND the
// GreenhouseCell type it returns. Dart extensions (Greenhouse.label) resolve
// only when their defining library is in scope, which a plain import of this
// file would not achieve.
export '../data/greenhouse_cells.dart';

/// Whether the picked cell is the visitor's position or their destination.
enum CellPickMode { start, destination }

/// Loaded once per app run; the asset is 6 KB and never changes at runtime.
List<GreenhouseCell>? _cache;

Future<List<GreenhouseCell>> loadGreenhouseCells() async {
  if (_cache != null) return _cache!;
  final raw = await rootBundle.loadString(greenhouseCellsAsset);
  return _cache = parseGreenhouseCells(raw);
}

/// Opens the picker. Resolves to the chosen cell, or null if dismissed.
Future<GreenhouseCell?> pickGreenhouseCell(
  BuildContext context, {
  required CellPickMode mode,
}) {
  return showModalBottomSheet<GreenhouseCell>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D1F14),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _CellPickerSheet(mode: mode),
  );
}

class _CellPickerSheet extends StatefulWidget {
  const _CellPickerSheet({required this.mode});
  final CellPickMode mode;

  @override
  State<_CellPickerSheet> createState() => _CellPickerSheetState();
}

class _CellPickerSheetState extends State<_CellPickerSheet> {
  late final Future<List<GreenhouseCell>> _future = loadGreenhouseCells();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isStart = widget.mode == CellPickMode.start;
    // Cap at 80% of the screen so the sheet never covers the whole map.
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            // Lift above the keyboard when the search field has focus.
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C5A44),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isStart ? 'Where are you now?' : 'Where do you want to go?',
                style: const TextStyle(
                  color: Color(0xFFE8F5E9),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap the cell marked on the greenhouse bench nearest to you.',
                style: TextStyle(color: Color(0xFF9CCC9F), fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: false,
                style: const TextStyle(color: Color(0xFFE8F5E9)),
                onChanged: (v) => setState(() => _query = v.trim().toUpperCase()),
                decoration: InputDecoration(
                  hintText: 'Search a cell, e.g. A12',
                  hintStyle: const TextStyle(color: Color(0xFF6E8A72)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF81C784)),
                  filled: true,
                  fillColor: const Color(0xFF13301A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<List<GreenhouseCell>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError || snap.data == null) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          "Couldn't load the greenhouse plan.",
                          style: TextStyle(color: Color(0xFFEF9A9A)),
                        ),
                      );
                    }
                    final all = snap.data!;
                    final shown = _query.isEmpty
                        ? all
                        : all.where((c) => c.name.contains(_query)).toList();
                    if (shown.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No cell with that name.',
                          style: TextStyle(color: Color(0xFF9CCC9F)),
                        ),
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        for (final house in Greenhouse.values)
                          ..._houseSection(cellsIn(shown, house), house),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _houseSection(List<GreenhouseCell> cells, Greenhouse house) {
    if (cells.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Text(
          '${house.label} greenhouse  ·  ${cells.length} cells',
          style: const TextStyle(
            color: Color(0xFF81C784),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in cells)
            ActionChip(
              label: Text(c.name),
              labelStyle: const TextStyle(
                color: Color(0xFFE8F5E9),
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: const Color(0xFF1B4020),
              side: const BorderSide(color: Color(0xFF2E7D32)),
              onPressed: () => Navigator.of(context).pop(c),
            ),
        ],
      ),
    ];
  }
}
