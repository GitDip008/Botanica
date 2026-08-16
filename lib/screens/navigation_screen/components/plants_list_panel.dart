/// PURPOSE:
/// This file implements the PlantsListPanel widget which displays the sliding panel
/// of discovered plants in a vertical, scrollable layout with pagination controls.
///
/// CONTEXT/PARENT FILE:
/// Used by 'navigation_screen.dart' to display API-discovered plants and page navigation.

import 'package:flutter/material.dart';
import 'package:botanica_ar/models/hankinta_plant.dart';

class PlantsListPanel extends StatelessWidget {
  final List<HankintaPlant> discoveredPlants;
  final HankintaPlant? selectedPlant;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final Size widgetSize;
  final Function(HankintaPlant) onPlantTap;
  final Function(int) onPageSelected;
  final VoidCallback onClose;

  const PlantsListPanel({
    super.key,
    required this.discoveredPlants,
    required this.selectedPlant,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.widgetSize,
    required this.onPlantTap,
    required this.onPageSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic max height based on screen size, up to 320px
    final panelHeight = (widgetSize.height * 0.42).clamp(240.0, 340.0);

    return Container(
      height: panelHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12.0,
            offset: const Offset(0.0, 4.0),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Plant Count and Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_florist,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 18.0,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'Discovered Plants (${discoveredPlants.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 16.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          const Divider(color: Colors.white12, height: 1.0),
          const SizedBox(height: 8.0),

          // Vertical Scrollable List of Plants
          Expanded(
            child: discoveredPlants.isEmpty
                ? const Center(
                    child: Text(
                      'No valid plant coordinates on this page.',
                      style: TextStyle(color: Colors.white54, fontSize: 11.0),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.vertical,
                    padding: const EdgeInsets.only(bottom: 4.0),
                    itemCount: discoveredPlants.length,
                    itemBuilder: (context, index) {
                      final plant = discoveredPlants[index];
                      final isSelected = selectedPlant?.plantId == plant.plantId;

                      return GestureDetector(
                        onTap: () => onPlantTap(plant),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withOpacity(0.2)
                                : Theme.of(context)
                                    .scaffoldBackgroundColor
                                    .withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.secondary
                                  : Colors.white12,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.secondary
                                      : Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.eco,
                                  color: isSelected ? Colors.black : Colors.greenAccent,
                                  size: 16.0,
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plant.plantName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (plant.heimo != null && plant.heimo!.isNotEmpty)
                                      Text(
                                        plant.heimo!,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'X: ${plant.coordinateX.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Y: ${plant.coordinateY.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontSize: 10.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6.0),
          const Divider(color: Colors.white12, height: 1.0),
          const SizedBox(height: 6.0),

          // Pagination Bar (Total pages & Page Selector)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total pages: $totalPages ($totalItems total)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  // Previous Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20.0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: currentPage > 1 ? Colors.white : Colors.white24,
                    onPressed: currentPage > 1
                        ? () => onPageSelected(currentPage - 1)
                        : null,
                  ),
                  // Current Page Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 3.0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$currentPage / $totalPages',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Next Page Button
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20.0),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: currentPage < totalPages ? Colors.white : Colors.white24,
                    onPressed: currentPage < totalPages
                        ? () => onPageSelected(currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
