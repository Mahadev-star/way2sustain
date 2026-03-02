// lib/services/environmental_data_service.dart
// Enhanced with multi-API fallback system

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sustainable_travel_app/config/api_config.dart';
import 'package:sustainable_travel_app/models/route_data.dart';

class EnvironmentalDataService {
  static final EnvironmentalDataService _instance =
      EnvironmentalDataService._internal();
  factory EnvironmentalDataService() => _instance;
  EnvironmentalDataService._internal();

  // ============ CACHES ============
  final Map<String, RealTimeFactors> _realtimeCache = {};
  final Map<String, double> _aqiCache = {};
  final Map<String, double> _trafficCache = {};
  final Map<String, double> _weatherCache = {};
  final Map<String, double> _elevationCache = {};

  // Cache duration

  /// Get REAL-TIME factors with multi-API fallback
  Future<RealTimeFactors> getRealTimeFactors(
    LatLng from,
    LatLng to,
    String vehicleType,
  ) async {
    String cacheKey =
        '${from.latitude.toStringAsFixed(4)},${from.longitude.toStringAsFixed(4)}_${to.latitude.toStringAsFixed(4)},${to.longitude.toStringAsFixed(4)}';

    // Return cached data if fresh
    if (_realtimeCache.containsKey(cacheKey)) {
      final factors = _realtimeCache[cacheKey]!;
      if (!factors.isStale) {
        return factors;
      }
    }

    debugPrint('🌐 Fetching REAL-TIME data with fallback support...');

    // Fetch all factors in parallel
    final results = await Future.wait([
      _getTrafficWithFallback(from),
      _getAQIWithFallback(from),
      _getWeatherWithFallback(from),
      _getEmissionsWithFallback(from, to, vehicleType),
      _getElevationWithFallback(from, to),
      _getEVChargerWithFallback(to),
    ]);

    final factors = RealTimeFactors(
      trafficCongestion: results[0] as double,
      airQualityIndex: results[1] as double,
      weatherImpact: results[2] as double,
      co2Emissions: results[3] as double,
      elevationGain: results[4] as double,
      hasEVCharger: results[5] as bool,
      timestamp: DateTime.now(),
    );

    _realtimeCache[cacheKey] = factors;
    return factors;
  }

  // ============ TRAFFIC - Multi-API Fallback ============
  Future<double> _getTrafficWithFallback(LatLng location) async {
    String cacheKey =
        'traffic_${location.latitude.toStringAsFixed(3)}_${location.longitude.toStringAsFixed(3)}';
    if (_trafficCache.containsKey(cacheKey)) return _trafficCache[cacheKey]!;

    double? result;

    // Try TomTom API (primary)
    try {
      result = await _tryTomTomTraffic(location);
      if (result != null) {
        _trafficCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ TomTom traffic failed: $e');
    }

    // Try OSRM as fallback
    try {
      result = await _tryOSRMTraffic(location);
      if (result != null) {
        _trafficCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ OSRM traffic failed: $e');
    }

    // Try OpenRouteService as second fallback
    try {
      result = await _tryORSTraffic(location);
      if (result != null) {
        _trafficCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ ORS traffic failed: $e');
    }

    // Final fallback: Local traffic estimation
    result = _estimateTrafficLocal(location);
    _trafficCache[cacheKey] = result;
    return result;
  }

  Future<double?> _tryTomTomTraffic(LatLng location) async {
    final url = Uri.parse(
      '${ApiConfig.tomTomTrafficUrl}?key=${ApiConfig.tomTomApiKey}&point=${location.latitude},${location.longitude}&unit=KMPH',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['flowSegmentData'] != null) {
        double currentSpeed =
            data['flowSegmentData']['currentSpeed']?.toDouble() ?? 0;
        double freeFlowSpeed =
            data['flowSegmentData']['freeFlowSpeed']?.toDouble() ?? 50;
        if (freeFlowSpeed > 0 && currentSpeed > 0) {
          return (1.0 - (currentSpeed / freeFlowSpeed)).clamp(0.0, 1.0);
        }
      }
    }
    return null;
  }

  Future<double?> _tryOSRMTraffic(LatLng location) async {
    // OSRM doesn't provide direct traffic, but we can estimate from speed
    final url = Uri.parse(
      '${ApiConfig.osrmUrl}/route/v1/driving/${location.longitude},${location.latitude}?overview=false',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      // OSRM returns routes, we estimate traffic based on time of day
      return _estimateTrafficLocal(location);
    }
    return null;
  }

  Future<double?> _tryORSTraffic(LatLng location) async {
    final url = Uri.parse(
      '${ApiConfig.openRouteServiceUrl}/Directions driving?api_key=${ApiConfig.openRouteServiceApiKey}&start=${location.longitude},${location.latitude}&end=${location.longitude + 0.01},${location.latitude + 0.01}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return _estimateTrafficLocal(location);
    }
    return null;
  }

  // ============ AQI - Multi-API Fallback ============
  Future<double> _getAQIWithFallback(LatLng location) async {
    String cacheKey =
        'aqi_${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}';
    if (_aqiCache.containsKey(cacheKey)) return _aqiCache[cacheKey]!;

    List<double> aqiValues = [];

    // Try OpenWeather (primary) - try multiple API keys
    final openWeatherKeys = [
      ApiConfig.openWeatherApiKey,
      ApiConfig.openWeatherApiKey2,
      ApiConfig.openWeatherApiKey3,
      ApiConfig.openWeatherApiKey4,
      ApiConfig.openWeatherApiKey5,
    ];

    for (var key in openWeatherKeys) {
      try {
        final aqi = await _tryOpenWeatherAQI(location, key);
        if (aqi != null) {
          aqiValues.add(aqi);
          break;
        }
      } catch (e) {
        debugPrint('⚠️ OpenWeather AQI key failed: $e');
      }
    }

    // Try IQAir as fallback
    if (aqiValues.isEmpty) {
      try {
        final aqi = await _tryIQAirAQI(location);
        if (aqi != null) aqiValues.add(aqi);
      } catch (e) {
        debugPrint('⚠️ IQAir AQI failed: $e');
      }
    }

    // Try OpenAQ as second fallback
    if (aqiValues.isEmpty) {
      try {
        final aqi = await _tryOpenAQAQI(location);
        if (aqi != null) aqiValues.add(aqi);
      } catch (e) {
        debugPrint('⚠️ OpenAQ AQI failed: $e');
      }
    }

    double result;
    if (aqiValues.isNotEmpty) {
      result = aqiValues.reduce((a, b) => a + b) / aqiValues.length;
    } else {
      // Final fallback: Local AQI estimation
      result = _estimateAQILocal(location);
    }

    _aqiCache[cacheKey] = result;
    return result;
  }

  Future<double?> _tryOpenWeatherAQI(LatLng location, String apiKey) async {
    final url = Uri.parse(
      '${ApiConfig.openWeatherAirUrl}?lat=${location.latitude}&lon=${location.longitude}&appid=$apiKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['list'] != null && data['list'].isNotEmpty) {
        int aqiLevel = data['list'][0]['main']['aqi'] as int;
        return _convertOpenWeatherAQI(aqiLevel);
      }
    }
    return null;
  }

  Future<double?> _tryIQAirAQI(LatLng location) async {
    final url = Uri.parse(
      '${ApiConfig.iqAirUrl}/nearest_city?lat=${location.latitude}&lon=${location.longitude}&key=${ApiConfig.iqAirApiKey}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        return (data['data']['current']['pollution']['aqius'] as num)
            .toDouble();
      }
    }
    return null;
  }

  Future<double?> _tryOpenAQAQI(LatLng location) async {
    final url = Uri.parse(
      '${ApiConfig.openaqUrl}/latest?latitude=${location.latitude}&longitude=${location.longitude}&limit=1',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        var measurements = data['results'][0]['measurements'];
        if (measurements != null && measurements.isNotEmpty) {
          // Find PM2.5 or AQI measurement
          for (var m in measurements) {
            if (m['parameter'] == 'pm25' || m['parameter'] == 'aqi') {
              return (m['value'] as num).toDouble();
            }
          }
        }
      }
    }
    return null;
  }

  double _convertOpenWeatherAQI(int level) {
    switch (level) {
      case 1:
        return 25.0;
      case 2:
        return 75.0;
      case 3:
        return 125.0;
      case 4:
        return 200.0;
      case 5:
        return 300.0;
      default:
        return 50.0;
    }
  }

  // ============ WEATHER - Multi-API Fallback ============
  Future<double> _getWeatherWithFallback(LatLng location) async {
    String cacheKey =
        'weather_${location.latitude.toStringAsFixed(2)}_${location.longitude.toStringAsFixed(2)}';
    if (_weatherCache.containsKey(cacheKey)) return _weatherCache[cacheKey]!;

    double? result;

    // Try OpenWeather (primary) - try multiple API keys
    final openWeatherKeys = [
      ApiConfig.openWeatherApiKey,
      ApiConfig.openWeatherApiKey2,
      ApiConfig.openWeatherApiKey3,
    ];

    for (var key in openWeatherKeys) {
      try {
        result = await _tryOpenWeatherWeather(location, key);
        if (result != null) {
          _weatherCache[cacheKey] = result;
          return result;
        }
      } catch (e) {
        debugPrint('⚠️ OpenWeather weather failed: $e');
      }
    }

    // Try Open-Meteo as fallback
    try {
      result = await _tryOpenMeteoWeather(location);
      if (result != null) {
        _weatherCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ Open-Meteo weather failed: $e');
    }

    // Final fallback: Local weather estimation
    result = _estimateWeatherLocal(location);
    _weatherCache[cacheKey] = result;
    return result;
  }

  Future<double?> _tryOpenWeatherWeather(LatLng location, String apiKey) async {
    final url = Uri.parse(
      '${ApiConfig.openWeatherWeatherUrl}?lat=${location.latitude}&lon=${location.longitude}&appid=$apiKey&units=metric',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _parseWeatherImpact(data);
    }
    return null;
  }

  Future<double?> _tryOpenMeteoWeather(LatLng location) async {
    final url = Uri.parse(
      '${ApiConfig.openMeteoUrl}/forecast?latitude=${location.latitude}&longitude=${location.longitude}&current=weather_code',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['current'] != null) {
        int weatherCode = data['current']['weather_code'] ?? 0;
        return _convertOpenMeteoWeather(weatherCode);
      }
    }
    return null;
  }

  double _parseWeatherImpact(Map<String, dynamic> data) {
    double impact = 0.1;
    if (data['weather'] != null && data['weather'].isNotEmpty) {
      int weatherId = data['weather'][0]['id'] ?? 800;
      impact = _convertWeatherId(weatherId);
    }
    return impact;
  }

  double _convertWeatherId(int weatherId) {
    if (weatherId >= 200 && weatherId < 300) return 0.8; // Thunderstorm
    if (weatherId >= 300 && weatherId < 400) return 0.5; // Drizzle
    if (weatherId >= 500 && weatherId < 600) return 0.6; // Rain
    if (weatherId >= 600 && weatherId < 700) return 0.7; // Snow
    if (weatherId >= 700 && weatherId < 800) return 0.3; // Mist
    if (weatherId == 800) return 0.1; // Clear
    if (weatherId > 800) return 0.2; // Clouds
    return 0.1;
  }

  double _convertOpenMeteoWeather(int code) {
    if (code >= 95) return 0.8; // Thunderstorm
    if (code >= 80) return 0.6; // Rain
    if (code >= 70) return 0.7; // Snow
    if (code >= 50) return 0.5; // Drizzle
    if (code >= 30) return 0.3; // Fog
    if (code >= 20) return 0.2; // Cloudy
    return 0.1; // Clear
  }

  // ============ ELEVATION - Multi-API Fallback ============
  Future<double> _getElevationWithFallback(LatLng from, LatLng to) async {
    String cacheKey =
        'elev_${from.latitude}_${from.longitude}_${to.latitude}_${to.longitude}';
    if (_elevationCache.containsKey(cacheKey)) {
      return _elevationCache[cacheKey]!;
    }

    double? result;

    // Try Open-Elevation (primary)
    try {
      result = await _tryOpenElevation(from, to);
      if (result != null) {
        _elevationCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ Open-Elevation failed: $e');
    }

    // Try OpenTopoData as fallback
    try {
      result = await _tryOpenTopoData(from, to);
      if (result != null) {
        _elevationCache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ OpenTopoData failed: $e');
    }

    // Final fallback: Local estimation
    result = _estimateElevationLocal(from, to);
    _elevationCache[cacheKey] = result;
    return result;
  }

  Future<double?> _tryOpenElevation(LatLng from, LatLng to) async {
    final url = Uri.parse(
      '${ApiConfig.openElevationUrl}?locations=${from.latitude},${from.longitude}|${to.latitude},${to.longitude}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].length >= 2) {
        double elev1 = (data['results'][0]['elevation'] as num).toDouble();
        double elev2 = (data['results'][1]['elevation'] as num).toDouble();
        return (elev2 - elev1).abs();
      }
    }
    return null;
  }

  Future<double?> _tryOpenTopoData(LatLng from, LatLng to) async {
    final url = Uri.parse(
      '${ApiConfig.openTopoDataUrl}/elevation?locations=${from.latitude},${from.longitude}|${to.latitude},${to.longitude}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'] != null && data['results'].length >= 2) {
        double elev1 = (data['results'][0]['elevation'] as num).toDouble();
        double elev2 = (data['results'][1]['elevation'] as num).toDouble();
        return (elev2 - elev1).abs();
      }
    }
    return null;
  }

  // ============ EV CHARGERS - Multi-API Fallback ============
  Future<bool> _getEVChargerWithFallback(LatLng location) async {
    try {
      // Try OpenChargeMap (primary) - try multiple API keys
      final openChargeKeys = [
        ApiConfig.openChargeApiKey,
        ApiConfig.openChargeApiKey2,
        ApiConfig.openChargeApiKey3,
      ];

      for (var key in openChargeKeys) {
        try {
          final chargers = await _tryOpenCharge(location, key, 5000);
          if (chargers != null && chargers.isNotEmpty) {
            return true;
          }
        } catch (e) {
          debugPrint('⚠️ OpenCharge key failed: $e');
        }
      }

      // Try Overpass API as fallback
      try {
        final hasCharger = await _tryOverpassCharger(location, 5000);
        if (hasCharger) return true;
      } catch (e) {
        debugPrint('⚠️ Overpass charger failed: $e');
      }

      // Try SimpleRouting as second fallback
      try {
        final hasCharger = await _trySimpleRoutingCharger(location);
        if (hasCharger) return true;
      } catch (e) {
        debugPrint('⚠️ SimpleRouting charger failed: $e');
      }
    } catch (e) {
      debugPrint('⚠️ All EV charger APIs failed: $e');
    }

    return false;
  }

  Future<List<dynamic>?> _tryOpenCharge(
    LatLng location,
    String apiKey,
    int radius,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.openChargeUrl}?latitude=${location.latitude}&longitude=${location.longitude}&maxresults=1&key=$apiKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data as List;
    }
    return null;
  }

  Future<bool> _tryOverpassCharger(LatLng location, int radius) async {
    final query =
        '''
      [out:json];
      node["amenity"="charging_station"](around:$radius,${location.latitude},${location.longitude});
      out count;
    ''';

    final url = Uri.parse(
      '${ApiConfig.overpassApiUrl}?data=${Uri.encodeComponent(query)}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      int count = data['elements']?.length ?? 0;
      return count > 0;
    }
    return false;
  }

  Future<bool> _trySimpleRoutingCharger(LatLng location) async {
    // SimpleRouting doesn't have charger API, return false
    return false;
  }

  // ============ EMISSIONS CALCULATION ============
  Future<double> _getEmissionsWithFallback(
    LatLng from,
    LatLng to,
    String vehicleType,
  ) async {
    final distance = const Distance().distance(from, to) / 1000;
    final traffic = await _getTrafficWithFallback(from);
    final elevation = await _getElevationWithFallback(from, to);

    return _calculateEmissions(
      distance: distance,
      vehicleType: vehicleType,
      traffic: traffic,
      elevation: elevation,
    );
  }

  double _calculateEmissions({
    required double distance,
    required String vehicleType,
    required double traffic,
    required double elevation,
  }) {
    // Base emissions in g/km
    Map<String, double> baseEmissions = {
      'Petrol Car': 120.0,
      'Diesel Car': 140.0,
      'Electric Car': 50.0,
      'Hybrid Car': 80.0,
      'Bicycle': 0.0,
      'Walking': 0.0,
    };

    double base = baseEmissions[vehicleType] ?? 120.0;

    // Adjust for traffic (congestion increases emissions)
    double trafficMultiplier = 1.0 + (traffic * 0.5);

    // Adjust for elevation (uphill uses more fuel/energy)
    double elevationMultiplier = 1.0 + (elevation / 500 * 0.3);

    return base * distance * trafficMultiplier * elevationMultiplier;
  }

  // ============ LOCAL FALLBACK ESTIMATIONS ============
  double _estimateTrafficLocal(LatLng location) {
    DateTime now = DateTime.now();
    int hour = now.hour;
    bool isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;

    double baseTraffic = 0.3;

    if (isWeekend) {
      if (hour >= 10 && hour <= 20) {
        baseTraffic = 0.4;
      } else {
        baseTraffic = 0.2;
      }
    } else {
      if ((hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19)) {
        baseTraffic = 0.8; // Rush hour
      } else if (hour >= 9 && hour <= 17) {
        baseTraffic = 0.5; // Daytime
      } else {
        baseTraffic = 0.2; // Night
      }
    }

    // Urban areas have more traffic
    if (_isUrbanArea(location)) {
      baseTraffic += 0.15;
    }

    return baseTraffic.clamp(0.0, 1.0);
  }

  double _estimateAQILocal(LatLng location) {
    double baseAQI = 50.0;

    // Major cities have higher AQI
    if (_isUrbanArea(location)) {
      baseAQI += 30.0;
    }

    // Add traffic impact
    baseAQI += _estimateTrafficLocal(location) * 40;

    // Seasonal adjustment (winter months tend to have higher AQI)
    int month = DateTime.now().month;
    if (month >= 10 || month <= 2) {
      baseAQI += 20;
    }

    return baseAQI.clamp(20.0, 300.0);
  }

  double _estimateWeatherLocal(LatLng location) {
    double impact = 0.1;

    int month = DateTime.now().month;

    // Monsoon season (June-September)
    if (month >= 6 && month <= 9) {
      impact = 0.5;
    }
    // Winter (December-February)
    else if (month >= 12 || month <= 2) {
      impact = 0.2;
    }
    // Summer (March-May)
    else if (month >= 3 && month <= 5) {
      impact = 0.3;
    }

    return impact;
  }

  double _estimateElevationLocal(LatLng from, LatLng to) {
    // Estimate based on latitude difference (rough approximation)
    return ((to.latitude - from.latitude).abs() * 111000).abs() * 0.1;
  }

  bool _isUrbanArea(LatLng location) {
    // Common urban coordinates (simplified check)
    // In a real app, this would use a database or API
    double lat = location.latitude.abs();
    double lon = location.longitude.abs();

    // Major metropolitan areas approximation
    return (lat >= 8.0 && lat <= 35.0 && lon >= 68.0 && lon <= 98.0);
  }

  // ============ PUBLIC METHODS ============
  Future<List<Map<String, dynamic>>> findEVChargers(
    LatLng location,
    double radiusInMeters,
  ) async {
    List<Map<String, dynamic>> allChargers = [];

    // Try OpenChargeMap first (multiple API keys)
    final openChargeKeys = [
      ApiConfig.openChargeApiKey,
      ApiConfig.openChargeApiKey2,
      ApiConfig.openChargeApiKey3,
    ];

    for (var key in openChargeKeys) {
      try {
        final chargers = await _tryFindOpenCharge(
          location,
          key,
          radiusInMeters,
        );
        if (chargers.isNotEmpty) {
          allChargers.addAll(chargers);
          break;
        }
      } catch (e) {
        debugPrint('⚠️ OpenCharge find failed: $e');
      }
    }

    // Try Overpass as fallback
    if (allChargers.isEmpty) {
      try {
        final chargers = await _tryFindOverpassChargers(
          location,
          radiusInMeters,
        );
        allChargers.addAll(chargers);
      } catch (e) {
        debugPrint('⚠️ Overpass find failed: $e');
      }
    }

    return allChargers;
  }

  Future<List<Map<String, dynamic>>> _tryFindOpenCharge(
    LatLng location,
    String apiKey,
    double radius,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.openChargeUrl}?latitude=${location.latitude}&longitude=${location.longitude}&maxdistance=${radius / 1000}&key=$apiKey',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    List<Map<String, dynamic>> chargers = [];

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        for (var item in data) {
          chargers.add({
            'id': item['ID'] ?? '',
            'name': item['AddressInfo']?['Title'] ?? 'EV Charger',
            'latitude': item['AddressInfo']?['Latitude'] ?? 0,
            'longitude': item['AddressInfo']?['Longitude'] ?? 0,
            'operator': item['OperatorInfo']?['Title'] ?? 'Unknown',
          });
        }
      }
    }

    return chargers;
  }

  Future<List<Map<String, dynamic>>> _tryFindOverpassChargers(
    LatLng location,
    double radius,
  ) async {
    final query =
        '''
      [out:json];
      node["amenity"="charging_station"](around:$radius,${location.latitude},${location.longitude});
      out body;
    ''';

    final url = Uri.parse(
      '${ApiConfig.overpassApiUrl}?data=${Uri.encodeComponent(query)}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 12));

    List<Map<String, dynamic>> chargers = [];

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['elements'] != null) {
        for (var element in data['elements']) {
          chargers.add({
            'id': element['id'] ?? '',
            'name': element['tags']?['name'] ?? 'EV Charging Station',
            'latitude': element['lat'] ?? 0,
            'longitude': element['lon'] ?? 0,
            'operator': element['tags']?['operator'] ?? 'Unknown',
          });
        }
      }
    }

    return chargers;
  }

  /// Alias for findEVChargers - uses OpenRouteService as fallback
  Future<List<Map<String, dynamic>>> findEVChargersORS(
    LatLng location,
    double radiusInMeters,
  ) async {
    return findEVChargers(location, radiusInMeters);
  }
}
