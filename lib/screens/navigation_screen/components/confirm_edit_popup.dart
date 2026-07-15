/// PURPOSE:
/// This file implements the ConfirmEditPopup widget which prompts the user to confirm
/// updating a plant's location coordinate on the map.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize editing confirm overlays.
///
/// INPUTS / PARAMETERS:
/// - tempEditPoint (MapPoint?, Required): The prospective coordinate chosen by the user.
/// - editingPlant (MockPlantInfo?, Required): The plant whose location is being edited.
/// - cadToPixel (Offset Function(MapPoint), Required): Transformation mapping CAD space to pixel space.
/// - widgetSize (Size, Required): Viewport dimensions.
/// - onConfirm (VoidCallback, Required): Action when "Confirm" is pressed.
/// - onCancel (VoidCallback, Required): Action when "Cancel" is pressed.

import 'package:flutter/material.dart';
import 'package:botanica_ar/models/mock_plant.dart';
import '../navigation_screen.dart' show MapPoint;

class ConfirmEditPopup extends StatelessWidget {
  final MapPoint? tempEditPoint;
  final MockPlantInfo? editingPlant;
  final Offset Function(MapPoint) cadToPixel;
  final Size widgetSize;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmEditPopup({
    super.key,
    required this.tempEditPoint,
    required this.editingPlant,
    required this.cadToPixel,
    required this.widgetSize,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (tempEditPoint == null || editingPlant == null) return const SizedBox.shrink();

    final pixel = cadToPixel(tempEditPoint!);

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
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8.0,
                offset: const Offset(0.0, 4.0),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Location Update',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white12, height: 10.0),
              Text(
                'Update "${editingPlant!.plantName}" to:',
                style: const TextStyle(color: Colors.white70, fontSize: 10.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4.0),
              Text(
                'X: ${tempEditPoint!.x.toStringAsFixed(2)}\nY: ${tempEditPoint!.y.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10.0),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 0.8),
                        ),
                        child: Center(
                          child: Text(
                            'Confirm',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 10.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: GestureDetector(
                      onTap: onCancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: const Color(0xFFEF5350), width: 0.8),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFFEF5350),
                              fontSize: 10.0,
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
