/// PURPOSE:
/// This file implements the DestinationMarker widget which renders the target location pin
/// on the indoor map screen as a custom coral/red pin containing a botanical leaf icon.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map markers.
///
/// INPUTS / PARAMETERS:
/// None.

import 'package:flutter/material.dart';

class DestinationMarker extends StatelessWidget {
  const DestinationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Small shadow at base
        Container(
          width: 6.0,
          height: 3.0,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(6.0, 3.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
        ),
        // Pin body
        Container(
          margin: const EdgeInsets.only(bottom: 2.0),
          padding: const EdgeInsets.all(2.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEF5350),
            border: Border.all(color: Colors.white, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF5350).withOpacity(0.4),
                blurRadius: 3.0,
                offset: const Offset(0.0, 1.5),
              ),
            ],
          ),
          child: const Icon(
            Icons.eco, // beautiful botanical leaf icon
            color: Colors.white,
            size: 9.0,
          ),
        ),
      ],
    );
  }
}
