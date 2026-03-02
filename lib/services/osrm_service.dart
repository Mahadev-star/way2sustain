// OSRM Service - Real Route Generation
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSRMService {
  static const String _baseUrl = 'https://routing.openstreetmap.de/routed-car';

  /// Get real route from OSRM
  Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
    String profile = 'driving',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/$profile/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates
              .map((c) => LatLng(c[1] as double, c[0] as double))
              .toList();
        }
      }
    } catch (e) {
      // Try alternative OSRM server
      return _getRouteAlternative(start, end);
    }

    return _getRouteAlternative(start, end);
  }

  /// Alternative OSRM server
  Future<List<LatLng>> _getRouteAlternative(LatLng start, LatLng end) async {
    try {
      // Try OSRM demo server
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;

          return coordinates
              .map((c) => LatLng(c[1] as double, c[0] as double))
              .toList();
        }
      }
    } catch (e) {
      // Return empty list if all attempts fail
      print('OSRM Error: $e');
    }

    return [];
  }

  /// Get route with waypoints for different route types
  Future<Map<String, List<LatLng>>> getMultipleRoutes({
    required LatLng start,
    required LatLng end,
  }) async {
    // Get direct route
    final directRoute = await getRoute(start: start, end: end);

    // Calculate offsets for alternative routes
    final latDiff = end.latitude - start.latitude;
    final lngDiff = end.longitude - start.longitude;

    // Perpendicular direction
    final perpLat = -lngDiff;
    final perpLng = latDiff;
    final perpLen = (perpLat * perpLat + perpLng * perpLng);

    LatLng? via1;
    LatLng? via2;

    if (perpLen > 0) {
      final normPerpLat = perpLat / perpLen * 0.15;
      final normPerpLng = perpLng / perpLen * 0.15;

      // Calculate waypoint for scenic route
      final midLat = (start.latitude + end.latitude) / 2;
      final midLng = (start.longitude + end.longitude) / 2;

      via1 = LatLng(midLat + normPerpLat * 0.5, midLng + normPerpLng * 0.5);

      via2 = LatLng(midLat - normPerpLat * 0.3, midLng - normPerpLng * 0.3);
    }

    // Get alternative routes via waypoints
    List<LatLng> scenicRoute = [];
    List<LatLng> balancedRoute = [];

    if (via1 != null) {
      scenicRoute = await getRoute(start: start, end: via1);
      final secondLeg = await getRoute(start: via1, end: end);
      scenicRoute.addAll(secondLeg.skip(1));
    }

    if (via2 != null) {
      balancedRoute = await getRoute(start: start, end: via2);
      final secondLeg = await getRoute(start: via2, end: end);
      balancedRoute.addAll(secondLeg.skip(1));
    }

    return {
      'direct': directRoute,
      'scenic': scenicRoute.isNotEmpty ? scenicRoute : directRoute,
      'balanced': balancedRoute.isNotEmpty ? balancedRoute : directRoute,
    };
  }
}
