import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Load EV stations from local JSON
  List<Map<String, dynamic>>? _evStations;

  /// Load EV stations from local JSON asset
  Future<void> _loadEVStations() async {
    if (_evStations != null) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/indian_ev_stations.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);
      _evStations = List<Map<String, dynamic>>.from(data['stations'] ?? []);
    } catch (e) {
      _evStations = [];
    }
  }

  /// Get elevation for a location
  Future<double> getElevation(LatLng point) async {
    // Use simple coordinate-based estimation
    return (point.latitude * 10).abs() % 100; // Simplified
  }

  /// Check if there's an EV charger nearby using LOCAL data
  Future<bool> isEVChargerNearby(
    LatLng location, {
    double radiusMeters = 10000.0, // 10km default for India
  }) async {
    await _loadEVStations();
    if (_evStations == null || _evStations!.isEmpty) return false;

    final chargers = await findNearbyEVChargers(location, radiusMeters);
    return chargers.isNotEmpty;
  }

  /// Find EV charging stations nearby using LOCAL data
  Future<List<Map<String, dynamic>>> findNearbyEVChargers(
    LatLng location,
    double radiusInMeters,
  ) async {
    await _loadEVStations();
    if (_evStations == null || _evStations!.isEmpty) return [];

    const Distance distance = Distance();
    List<Map<String, dynamic>> nearby = [];

    for (var station in _evStations!) {
      final stationLoc = LatLng(
        station['lat'] as double,
        station['lng'] as double,
      );

      final dist = distance.as(LengthUnit.Meter, location, stationLoc);

      if (dist <= radiusInMeters) {
        nearby.add({
          'id': station['name'],
          'name': station['name'],
          'location': stationLoc,
          'city': station['city'],
          'state': station['state'],
          'distance': dist,
          'distanceFromRoute': dist,
          'capacity': 'Unknown',
        });
      }
    }

    // Sort by distance
    nearby.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    return nearby;
  }

  /// Get current location (placeholder - use device GPS)
  Future<LatLng?> getCurrentLocation() async {
    // This would integrate with geolocator package
    return null;
  }
}
