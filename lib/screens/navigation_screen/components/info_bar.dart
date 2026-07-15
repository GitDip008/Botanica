/// PURPOSE:
/// This file implements the InfoBar widget which displays active BLE scanner status,
/// user positioning metrics, and A* route metadata in a compact footer panel.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map footer panel.
///
/// INPUTS / PARAMETERS:
/// - startMarker (MapPoint?, Optional): Current user location CAD coordinate.
/// - endMarker (MapPoint?, Optional): Current destination location CAD coordinate.
/// - userPosition (MapPoint?, Optional): Initial user location CAD coordinate.
/// - destination (MapPoint?, Optional): Initial destination location CAD coordinate.
/// - liveRssiCount (int, Required): Count of active Bluetooth beacons scanned.
/// - computedPathLength (int, Required): Count of nodes inside the computed path.

import 'package:flutter/material.dart';
import '../navigation_screen.dart' show MapPoint;

class InfoBar extends StatelessWidget {
  final MapPoint? startMarker;
  final MapPoint? endMarker;
  final MapPoint? userPosition;
  final MapPoint? destination;
  final int liveRssiCount;
  final int computedPathLength;

  const InfoBar({
    super.key,
    required this.startMarker,
    required this.endMarker,
    required this.userPosition,
    required this.destination,
    required this.liveRssiCount,
    required this.computedPathLength,
  });

  @override
  Widget build(BuildContext context) {
    final hasPath = computedPathLength > 0;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // User position info
            Icon(Icons.my_location, color: Theme.of(context).colorScheme.secondary, size: 8.0),
            const SizedBox(width: 8.0),
            Text(
              startMarker != null
                  ? 'User: (${startMarker!.x.toStringAsFixed(1)}, ${startMarker!.y.toStringAsFixed(1)})'
                  : (userPosition != null
                      ? 'User: (${userPosition!.x.toStringAsFixed(1)}, ${userPosition!.y.toStringAsFixed(1)})'
                      : 'User: –'),
              style: const TextStyle(color: Colors.white70, fontSize: 8.0),
            ),
            const SizedBox(width: 16.0),
            // Destination info
            const Icon(Icons.place, color: Color(0xFFEF5350), size: 8.0),
            const SizedBox(width: 8.0),
            Text(
              destination != null
                  ? 'Dest: (${destination!.x.toStringAsFixed(1)}, ${destination!.y.toStringAsFixed(1)})'
                  : (endMarker != null
                      ? 'Dest: (${endMarker!.x.toStringAsFixed(1)}, ${endMarker!.y.toStringAsFixed(1)})'
                      : 'Dest: –'),
              style: const TextStyle(color: Colors.white70, fontSize: 9.0),
            ),
            if (liveRssiCount > 0) ...[
              const SizedBox(width: 16.0),
              Icon(Icons.bluetooth, color: Theme.of(context).colorScheme.secondary, size: 8.0),
              const SizedBox(width: 4.0),
              Text(
                'Beacons: $liveRssiCount',
                style: const TextStyle(color: Colors.white70, fontSize: 8.0),
              ),
            ],
            const Spacer(),
            // Path node count
            if (hasPath)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 4.0,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  '$computedPathLength nodes',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12.0,
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
///
