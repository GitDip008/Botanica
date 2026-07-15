/// PURPOSE:
/// This file implements the TapPopup widget which displays when the user taps on the map,
/// prompting them to choose whether to set the tapped point as the start or destination.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map selection overlays.
///
/// INPUTS / PARAMETERS:
/// - tappedPoint (MapPoint?, Required): The coordinate tapped by the user.
/// - tappedPixel (Offset?, Required): The local screen offset where the user tapped.
/// - widgetSize (Size, Required): Viewport dimensions.
/// - onDismiss (VoidCallback, Required): Action when "Dismiss" (close) button is tapped.
/// - onSetAsStart (VoidCallback, Required): Action when "Start" button is tapped.
/// - onSetAsDestination (VoidCallback, Required): Action when "Destination" button is tapped.

import 'package:flutter/material.dart';
import '../navigation_screen.dart' show MapPoint;

class TapPopup extends StatelessWidget {
  final MapPoint? tappedPoint;
  final Offset? tappedPixel;
  final Size widgetSize;
  final VoidCallback onDismiss;
  final VoidCallback onSetAsStart;
  final VoidCallback onSetAsDestination;

  const TapPopup({
    super.key,
    required this.tappedPoint,
    required this.tappedPixel,
    required this.widgetSize,
    required this.onDismiss,
    required this.onSetAsStart,
    required this.onSetAsDestination,
  });

  @override
  Widget build(BuildContext context) {
    if (tappedPoint == null || tappedPixel == null) return const SizedBox.shrink();

    const popupW = 200.0;
    const popupH = 110.0;
    const margin = 8.0;

    // Calculate popup position — display above the tap point, centered on X
    double left = tappedPixel!.dx - popupW / 2;
    double top = tappedPixel!.dy - popupH - 12;

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
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8.0,
                offset: const Offset(0.0, 4.0),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10.0),
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
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white60,
                      size: 14.0,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 10.0),
              // CAD Coordinates
              Text(
                'X: ${tappedPoint!.x.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11.0),
              ),
              Text(
                'Y: ${tappedPoint!.y.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11.0),
              ),
              const SizedBox(height: 8.0),
              // Question
              const Text(
                'Set as:',
                style: TextStyle(color: Colors.white54, fontSize: 10.0),
              ),
              const SizedBox(height: 6.0),
              // 2 buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSetAsStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6.0),
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
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: GestureDetector(
                      onTap: onSetAsDestination,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6.0),
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
                              fontSize: 11.0,
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
}
