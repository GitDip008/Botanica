/// PURPOSE:
/// This file implements the UserMarker widget which renders the user's current estimated location
/// on the indoor map screen as a pulsing green circle ring with a white-bordered deep green solid core.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to modularize map markers.
///
/// INPUTS / PARAMETERS:
/// None.

import 'package:flutter/material.dart';

class UserMarker extends StatefulWidget {
  const UserMarker({super.key});

  @override
  State<UserMarker> createState() => _UserMarkerState();
}

class _UserMarkerState extends State<UserMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            Container(
              width: 30.0 * _pulse.value,
              height: 30.0 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF66BB6A).withOpacity(0.3 * (1 - _pulse.value + 0.5)),
              ),
            ),
            // Core dot
            Container(
              width: 10.0,
              height: 10.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.6),
                    blurRadius: 5.0,
                    spreadRadius: 1.0,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
