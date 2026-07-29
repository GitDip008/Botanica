// lib/navigation/nav_routes.dart
//
// Lightweight navigation helpers for the vendored BotaniNav module.
//
// The original module used go_router with deep links (botanicnav://). Inside
// Botanica it is mounted on the app's normal Navigator instead, so we replace
// go_router with plain Navigator pushes. ProviderScope lives at the app root
// (see main.dart), so every pushed nav screen shares the same riverpod state.

import 'package:flutter/material.dart';
import 'screens/plant_list_screen.dart';

abstract final class NavRoutes {
  /// Route name given to the module's home (plant list). Used by deep screens
  /// to pop straight back to the list with [backToPlantList].
  static const home = 'nav_plant_list';
}

/// OSM-compatible dark basemap tiles (CartoDB) — matches Botanica's dark UI and
/// needs no API key or billing, unlike Google Maps.
const String kNavTileUrl =
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const String kNavTileUserAgent = 'com.botanica.ar';

/// Entry point — opens the navigation feature (plant list) from anywhere in the
/// Botanica app.
void openNavigationModule(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: NavRoutes.home),
      builder: (_) => const PlantListScreen(),
    ),
  );
}

/// Pops back to the plant list, discarding any navigation/arrival screens above.
void backToPlantList(BuildContext context) {
  Navigator.of(context)
      .popUntil((r) => r.settings.name == NavRoutes.home || r.isFirst);
}
