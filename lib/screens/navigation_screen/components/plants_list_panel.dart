/// PURPOSE:
/// This file implements the PlantsListPanel widget which displays the sliding card panel
/// of nearby discovered plants at the bottom of the map screen.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to isolate plant list UI.
///
/// INPUTS / PARAMETERS:
/// - discoveredPlants (List<MockPlantInfo>, Required): List of MockPlantInfo objects found.
/// - selectedPlant (MockPlantInfo?, Optional): The currently selected plant.
/// - editingPlant (MockPlantInfo?, Optional): The plant currently undergoing position editing.
/// - widgetSize (Size, Required): Viewport dimensions.
/// - onPlantTap (Function(MockPlantInfo), Required): Callback when a plant card is tapped.
/// - onEditToggle (Function(MockPlantInfo), Required): Callback when the edit location button is toggled.
/// - onClose (VoidCallback, Required): Callback to clear the discovered plants list.

import 'package:flutter/material.dart';
import 'package:botanica_ar/models/mock_plant.dart';

class PlantsListPanel extends StatelessWidget {
  final List<MockPlantInfo> discoveredPlants;
  final MockPlantInfo? selectedPlant;
  final MockPlantInfo? editingPlant;
  final Size widgetSize;
  final Function(MockPlantInfo) onPlantTap;
  final Function(MockPlantInfo) onEditToggle;
  final VoidCallback onClose;

  const PlantsListPanel({
    super.key,
    required this.discoveredPlants,
    required this.selectedPlant,
    required this.editingPlant,
    required this.widgetSize,
    required this.onPlantTap,
    required this.onEditToggle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 165.0,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10.0,
            offset: const Offset(0.0, 4.0),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_florist,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 16.0,
                    ),
                    const SizedBox(width: 6.0),
                    const Text(
                      'Nearby Discoveries',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white60,
                    size: 16.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          // Horizontal list of plants
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              itemCount: discoveredPlants.length,
              itemBuilder: (context, index) {
                final plant = discoveredPlants[index];
                final isSelected = selectedPlant?.plantId == plant.plantId;
                final isEditingThis = editingPlant?.plantId == plant.plantId;

                return GestureDetector(
                  onTap: () => onPlantTap(plant),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 170.0,
                    margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: isEditingThis
                          ? const Color(0xFFEF5350).withOpacity(0.15)
                          : (isSelected
                              ? Theme.of(context).colorScheme.secondary.withOpacity(0.15)
                              : Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(12.0),
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
                              size: 16.0,
                            ),
                            const SizedBox(width: 6.0),
                            Expanded(
                              child: Text(
                                plant.plantName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'X: ${plant.coordinateX.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9.0,
                              ),
                            ),
                            Text(
                              'Y: ${plant.coordinateY.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        GestureDetector(
                          onTap: () => onEditToggle(plant),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isEditingThis
                                  ? const Color(0xFFEF5350)
                                  : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: Center(
                              child: Text(
                                isEditingThis ? 'Choose Position' : 'Edit Location',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.0,
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
}
