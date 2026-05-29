import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/api_config.dart';

/// Walking-route service backed by OpenRouteService (free, OSM-based).
///
/// Returns a list of [LatLng] points forming the route polyline, or null if
/// routing is unavailable (no key / network error / out of coverage).
class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const _baseUrl =
      'https://api.openrouteservice.org/v2/directions/foot-walking';

  bool get isConfigured =>
      ApiConfig.orsApiKey.isNotEmpty &&
      ApiConfig.orsApiKey != 'YOUR_OPENROUTESERVICE_KEY_HERE';

  /// Fetches a walking route from [start] to [end].
  /// Returns the polyline points, or null on any failure.
  Future<List<LatLng>?> walkingRoute(LatLng start, LatLng end) async {
    if (!isConfigured) return null;
    try {
      // ORS expects lon,lat order
      final uri = Uri.parse(
        '$_baseUrl?api_key=${ApiConfig.orsApiKey}'
        '&start=${start.longitude},${start.latitude}'
        '&end=${end.longitude},${end.latitude}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List?;
      if (features == null || features.isEmpty) return null;

      final geometry = features.first['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List;
      // coords are [lon, lat] pairs
      return coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
