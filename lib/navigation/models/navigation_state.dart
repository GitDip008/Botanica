// lib/models/navigation_state.dart
//
// Two model classes:
//   NavigationState  — real-time state pushed over WebSocket.
//   OutdoorRoute     — response from POST /api/v1/navigation/route.

import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NavigationState — WebSocket payload (/api/v1/navigation/ws/{session_id})
// ─────────────────────────────────────────────────────────────────────────────

class NavigationState extends Equatable {
  const NavigationState({
    required this.bearing,
    required this.distanceMetres,
    required this.hotColdScore,
    required this.hint,
    required this.waypointIndex,
    required this.arrived,
  });

  /// Degrees clockwise from north — used to compute arrow angle on device.
  /// Arrow angle = bearing - deviceCompassHeading (see compass_service.dart).
  final double bearing;

  /// Straight-line distance to the current target waypoint in metres.
  final double distanceMetres;

  /// 0.0 = freezing cold (far away) → 1.0 = burning hot (right on it).
  /// Consumed by HotColdGauge widget.
  final double hotColdScore;

  /// Human-readable hint, e.g. "Getting warmer" or "Getting colder".
  final String hint;

  /// Index of the current waypoint within the route steps list.
  final int waypointIndex;

  /// True when the user has arrived at the destination plant.
  final bool arrived;

  // ── Serialisation ──────────────────────────────────────────────────────────
  factory NavigationState.fromJson(Map<String, dynamic> json) =>
      NavigationState(
        bearing: (json['bearing'] as num).toDouble(),
        distanceMetres: (json['distance_metres'] as num).toDouble(),
        hotColdScore: (json['hot_cold_score'] as num).toDouble(),
        hint: json['hint'] as String,
        waypointIndex: json['waypoint_index'] as int,
        arrived: json['arrived'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'bearing': bearing,
        'distance_metres': distanceMetres,
        'hot_cold_score': hotColdScore,
        'hint': hint,
        'waypoint_index': waypointIndex,
        'arrived': arrived,
      };

  /// Convenience — initial waiting state before WS first message.
  static const loading = NavigationState(
    bearing: 0,
    distanceMetres: 0,
    hotColdScore: 0.5,
    hint: 'Calculating route…',
    waypointIndex: 0,
    arrived: false,
  );

  @override
  List<Object?> get props => [
        bearing,
        distanceMetres,
        hotColdScore,
        hint,
        waypointIndex,
        arrived,
      ];
}
