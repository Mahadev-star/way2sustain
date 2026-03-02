// Route Service - Uses OSRM + Python Backend for route calculation
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:sustainable_travel_app/models/route_data.dart';
import 'package:sustainable_travel_app/models/route_option.dart';
import 'package:sustainable_travel_app/services/environmental_data_service.dart';
import 'package:sustainable_travel_app/services/osrm_service.dart';
import 'package:sustainable_travel_app/services/prediction_service.dart';
import 'package:sustainable_travel_app/algorithms/eco_points_calculator.dart';
import 'package:sustainable_travel_app/config/api_config.dart';

class RouteService {
  late final OSRMService _osrmService;
  late final PredictionService _predictionService;

  // Selected date for predictions
  DateTime _selectedDate = DateTime.now();

  // Debug flag to force using ACO backend instead of OSRM
  // Set to true to see raw ACO-generated routes on the map
  // This allows visual inspection of the optimization logic without OSRM interference
  static const bool forceACOMode = true;

  RouteService() {
    _osrmService = OSRMService();
    _predictionService = PredictionService();
  }

  /// Update the selected date for predictions
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
  }

  /// Finds multiple route options - tries OSRM first, then backend
  Future<List<RouteOption>> findRouteOptions({
    required LatLng start,
    required LatLng end,
    required String vehicleType,
    List<LatLng>? waypoints,
    Function(double progress)? onProgress,
  }) async {
    // If forceACOMode is enabled, skip OSRM and use ACO backend directly
    // This displays raw ACO-generated node sequences directly on the map
    if (forceACOMode) {
      debugPrint('🔄 ACO Mode: Using raw ACO-generated node sequences');
      try {
        onProgress?.call(0.1);
        final routes = await _fetchFromBackend(
          start,
          end,
          vehicleType,
          onProgress,
        );
        if (routes.isNotEmpty) {
          debugPrint('✅ Using Python Backend (ACO) for route calculation');
          return routes;
        }
      } catch (e) {
        debugPrint('⚠️ Backend unavailable: $e');
      }
    } else {
      // Normal mode: Try OSRM first for real routes
      try {
        onProgress?.call(0.1);
        final osrmRoutes = await _fetchOSRMRoutes(
          start,
          end,
          vehicleType,
          onProgress,
        );
        if (osrmRoutes.isNotEmpty) {
          return osrmRoutes;
        }
      } catch (e) {
        debugPrint('OSRM Error: $e');
      }

      // Try backend (Python ACO)
      try {
        onProgress?.call(0.1);
        final routes = await _fetchFromBackend(
          start,
          end,
          vehicleType,
          onProgress,
        );
        if (routes.isNotEmpty) {
          debugPrint('✅ Using Python Backend for route calculation');
          return routes;
        }
      } catch (e) {
        debugPrint('⚠️ Backend unavailable: $e');
      }
    }

    // Fallback to geometric routes when both fail
    return _createFallbackOptions(
      start: start,
      end: end,
      vehicleType: vehicleType,
      onProgress: onProgress,
    );
  }

  /// Fetch real routes using OSRM
  Future<List<RouteOption>> _fetchOSRMRoutes(
    LatLng start,
    LatLng end,
    String vehicleType,
    Function(double progress)? onProgress,
  ) async {
    onProgress?.call(0.2);

    // Get multiple route types from OSRM
    final routes = await _osrmService.getMultipleRoutes(start: start, end: end);

    onProgress?.call(0.5);

    // Get predictions for selected date
    final dayOffset = _selectedDate.difference(DateTime.now()).inDays;
    final predictions = await _predictionService.getPredictions(
      start: start,
      end: end,
      vehicleType: vehicleType,
      numDays: 5,
    );

    // Get prediction for selected day
    DayPrediction? dayPrediction;
    if (dayOffset >= 0 && dayOffset < predictions.predictions.length) {
      dayPrediction = predictions.predictions[dayOffset];
    }

    // Use current day prediction as fallback
    dayPrediction ??= predictions.predictions.isNotEmpty
        ? predictions.predictions[0]
        : null;

    onProgress?.call(0.7);

    // Calculate baseline distance
    final baselineDistance = const Distance().distance(start, end) / 1000;
    final speed = _getVehicleSpeed(vehicleType);
    final baselineTime = (baselineDistance / speed) * 60;

    final options = <RouteOption>[];

    // Create route options from OSRM routes
    for (final entry in routes.entries) {
      final points = entry.value;
      if (points.isEmpty) continue;

      // Calculate distance and duration from actual route
      double totalDist = 0;
      for (int i = 1; i < points.length; i++) {
        totalDist += const Distance().distance(points[i - 1], points[i]);
      }
      final distanceKm = totalDist / 1000;
      final duration = (distanceKm / speed) * 60;

      // Apply prediction factors to route metrics
      double trafficMult = 1.0;
      double aqiValue = 50.0;

      if (dayPrediction != null) {
        trafficMult = 1.0 + (dayPrediction.trafficScore / 100) * 0.5;
        aqiValue = dayPrediction.aqiScore;
      }

      // Calculate emissions
      final baseEmissions = {
        'walking': 0.0,
        'bicycle': 0.0,
        'electric car': 50.0,
        'hybrid car': 80.0,
        'petrol car': 120.0,
        'diesel car': 140.0,
      };
      final base = baseEmissions[vehicleType.toLowerCase()] ?? 120.0;
      final co2 = base * distanceKm * trafficMult;

      final routeData = RouteData(
        points: points,
        distance: distanceKm,
        duration: duration,
        instructions: [],
        co2Emissions: co2,
        averageAQI: aqiValue,
        totalElevationGain: 0,
        trafficLevel: trafficMult.clamp(0.0, 1.0),
        weatherImpact: 0.1,
      );

      String type, description, icon;

      if (entry.key == 'scenic') {
        type = '🌱 ECO CHAMPION';
        description = 'Most environmentally friendly - scenic route';
        icon = '🌿';
      } else if (entry.key == 'balanced') {
        type = '⚖️ BALANCED';
        description = 'Best compromise between time and environment';
        icon = '⚖️';
      } else {
        type = '⏱️ QUICKEST';
        description = 'Fastest route - most direct path';
        icon = '⏱️';
      }

      options.add(
        RouteOption(
          type: type,
          description: description,
          icon: icon,
          routeData: routeData,
          ecoPoints: 0,
          timeVsBaseline: baselineTime > 0
              ? ((duration - baselineTime) / baselineTime * 100).round()
              : 0,
          co2Savings: 0,
          averageAQI: aqiValue,
          trafficLevel: trafficMult.clamp(0.0, 1.0),
        ),
      );
    }

    // Calculate eco points using the EcoPointsCalculator
    if (options.isNotEmpty) {
      final routeInputs = options
          .map(
            (opt) => RouteInput(
              routeId: opt.type,
              routeType: opt.type,
              distance: opt.routeData.distance,
              duration: opt.routeData.duration,
              co2Emissions: opt.routeData.co2Emissions,
              averageAQI: opt.routeData.averageAQI,
              trafficLevel: opt.routeData.trafficLevel,
              timeVsBaseline: opt.timeVsBaseline.toDouble(),
              vehicleType: vehicleType,
            ),
          )
          .toList();

      final calculatedRoutes = EcoPointsCalculator.calculateAllRoutes(
        routeInputs,
      );

      for (int i = 0; i < options.length && i < calculatedRoutes.length; i++) {
        final calc = calculatedRoutes[i];
        options[i] = RouteOption(
          type: options[i].type,
          description: options[i].description,
          icon: options[i].icon,
          routeData: options[i].routeData,
          ecoPoints: calc.ecoPoints,
          timeVsBaseline: options[i].timeVsBaseline,
          co2Savings: calc.co2Savings,
          averageAQI: options[i].averageAQI,
          trafficLevel: options[i].trafficLevel,
        );
      }
    }

    onProgress?.call(1.0);
    return options;
  }

  /// Fetch routes from Python backend API (uses ACO algorithm)
  Future<List<RouteOption>> _fetchFromBackend(
    LatLng start,
    LatLng end,
    String vehicleType,
    Function(double progress)? onProgress,
  ) async {
    final url = Uri.parse(
      '${ApiConfig.backendUrl}${ApiConfig.routeCalculateEndpoint}',
    );

    debugPrint('🔄 Calling backend: $url');

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'start_lat': start.latitude,
            'start_lng': start.longitude,
            'end_lat': end.latitude,
            'end_lng': end.longitude,
            'vehicle_type': vehicleType,
            'selected_date': _selectedDate.toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['status'] != 'success') {
      throw Exception(data['message'] ?? 'Backend error');
    }

    onProgress?.call(0.8);

    final routes = data['routes'] as List;
    final options = <RouteOption>[];

    for (final route in routes) {
      // Handle both formats of points:
      // 1. List of [lat, lng] arrays: [[lat, lng], [lat, lng], ...]
      // 2. List of {'lat': lat, 'lng': lng} objects: [{'lat': ..., 'lng': ...}, ...]
      final points = (route['points'] as List)
          .map((p) {
            double lat, lng;
            if (p is List) {
              // Format: [lat, lng]
              lat = (p[0] as num).toDouble();
              lng = (p[1] as num).toDouble();
            } else if (p is Map) {
              // Format: {'lat': lat, 'lng': lng}
              lat = (p['lat'] as num).toDouble();
              lng = (p['lng'] as num).toDouble();
            } else {
              // Fallback - skip invalid point
              return null;
            }
            return LatLng(lat, lng);
          })
          .whereType<LatLng>()
          .toList();

      String type = route['type'] as String;

      // Handle potential type mismatches for numeric fields
      final distance = _parseNumeric(route['distance']);
      final duration = _parseNumeric(route['duration']);
      final ecoPoints = _parseNumeric(route['eco_points']).toInt();
      final timeVsBaseline = _parseNumeric(route['time_vs_baseline']).toInt();
      final co2Savings = _parseNumeric(route['co2_savings']);

      final routeData = RouteData(
        points: points,
        distance: distance,
        duration: duration,
        instructions: [],
        co2Emissions: co2Savings,
        averageAQI: 50.0,
        totalElevationGain: 0.0,
        trafficLevel: 0.3,
        weatherImpact: 0.1,
      );

      options.add(
        RouteOption(
          type: type,
          description: route['description'] as String? ?? 'Route',
          icon: route['icon'] as String? ?? '🌿',
          routeData: routeData,
          ecoPoints: ecoPoints,
          timeVsBaseline: timeVsBaseline,
          co2Savings: co2Savings,
          averageAQI: 50.0,
          trafficLevel: 0.3,
        ),
      );
    }

    onProgress?.call(1.0);
    return options;
  }

  /// Create geometric fallback routes when OSRM and backend fail
  Future<List<RouteOption>> _createFallbackOptions({
    required LatLng start,
    required LatLng end,
    required String vehicleType,
    Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.3);

    RealTimeFactors.fallback(vehicleType);
    onProgress?.call(0.5);
    onProgress?.call(0.7);

    // Create distinct fallback routes using geometric curves
    final ecoRoute = _createGeometricRoute(start, end, vehicleType, 'eco');
    final balancedRoute = _createGeometricRoute(
      start,
      end,
      vehicleType,
      'balanced',
    );
    final quickRoute = _createGeometricRoute(
      start,
      end,
      vehicleType,
      'quickest',
    );

    final baselineDistance = const Distance().distance(start, end) / 1000;
    onProgress?.call(1.0);

    return [
      RouteOption(
        type: '🌱 ECO CHAMPION',
        description: 'Most environmentally friendly route',
        icon: '🌿',
        routeData: ecoRoute,
        ecoPoints: 60,
        timeVsBaseline: _calculateTimeVsBaseline(
          ecoRoute.duration,
          baselineDistance,
          vehicleType,
        ),
        co2Savings: ecoRoute.co2Savings,
        averageAQI: ecoRoute.averageAQI,
        trafficLevel: ecoRoute.trafficLevel,
      ),
      RouteOption(
        type: '⚖️ BALANCED',
        description: 'Best compromise between time and environment',
        icon: '⚖️',
        routeData: balancedRoute,
        ecoPoints: 30,
        timeVsBaseline: _calculateTimeVsBaseline(
          balancedRoute.duration,
          baselineDistance,
          vehicleType,
        ),
        co2Savings: balancedRoute.co2Savings,
        averageAQI: balancedRoute.averageAQI,
        trafficLevel: balancedRoute.trafficLevel,
      ),
      RouteOption(
        type: '⏱️ QUICKEST',
        description: 'Fastest route (0 eco points)',
        icon: '⏱️',
        routeData: quickRoute,
        ecoPoints: 0,
        timeVsBaseline: _calculateTimeVsBaseline(
          quickRoute.duration,
          baselineDistance,
          vehicleType,
        ),
        co2Savings: quickRoute.co2Savings,
        averageAQI: quickRoute.averageAQI,
        trafficLevel: quickRoute.trafficLevel,
      ),
    ];
  }

  /// Create visually distinct routes with curves using geometric calculations
  RouteData _createGeometricRoute(
    LatLng start,
    LatLng end,
    String vehicleType,
    String routeType,
  ) {
    final points = <LatLng>[start];

    final latDiff = end.latitude - start.latitude;
    final lngDiff = end.longitude - start.longitude;

    // Perpendicular direction for curve offset
    final perpLat = -lngDiff;
    final perpLng = latDiff;
    final perpLength = math.sqrt(perpLat * perpLat + perpLng * perpLng);
    final normPerpLat = perpLength > 0 ? perpLat / perpLength : 0.0;
    final normPerpLng = perpLength > 0 ? perpLng / perpLength : 0.0;

    final directDistance = const Distance().distance(start, end);

    // Different parameters for each route type
    int numPoints;
    double maxOffsetPercent;
    double curveDirection;
    double curvePattern;

    if (routeType == 'eco') {
      numPoints = 50;
      maxOffsetPercent = 0.35;
      curveDirection = 1.0;
      curvePattern = 1;
    } else if (routeType == 'balanced') {
      numPoints = 30;
      maxOffsetPercent = 0.18;
      curveDirection = -0.7;
      curvePattern = 2;
    } else {
      numPoints = 15;
      maxOffsetPercent = 0.05;
      curveDirection = 0.3;
      curvePattern = 3;
    }

    final maxOffset = directDistance * maxOffsetPercent;

    for (int i = 1; i < numPoints; i++) {
      final t = i / numPoints;

      double curve;
      switch (curvePattern.toInt()) {
        case 1:
          curve = math.sin(t * math.pi);
          break;
        case 2:
          curve = (1 - math.cos(t * math.pi)) / 2;
          break;
        case 3:
        default:
          curve = math.sin(t * math.pi * 1.5) * 0.3;
          break;
      }

      final curveOffset = curve * curveDirection;

      final baseLat = start.latitude + latDiff * t;
      final baseLng = start.longitude + lngDiff * t;

      final perpOffset = curveOffset * maxOffset;
      final lat = baseLat + normPerpLat * perpOffset;
      final lng = baseLng + normPerpLng * perpOffset;

      points.add(LatLng(lat, lng));
    }

    points.add(end);

    // Calculate total distance
    double totalDist = 0;
    for (int i = 1; i < points.length; i++) {
      totalDist += const Distance().distance(points[i - 1], points[i]);
    }

    final distanceKm = totalDist / 1000;
    final speed = _getVehicleSpeed(vehicleType);
    final duration = (distanceKm / speed) * 60;

    // Calculate emissions
    final baseEmissions = {
      'walking': 0.0,
      'bicycle': 0.0,
      'electric car': 50.0,
      'hybrid car': 80.0,
      'petrol car': 120.0,
      'diesel car': 140.0,
    };
    final base = baseEmissions[vehicleType.toLowerCase()] ?? 120.0;
    double trafficMult = routeType == 'eco'
        ? 0.7
        : (routeType == 'quickest' ? 1.3 : 1.0);
    double co2 = base * distanceKm * trafficMult;

    final envData = RealTimeFactors.fallback(vehicleType);

    return RouteData(
      points: points,
      distance: distanceKm,
      duration: duration,
      instructions: [],
      co2Emissions: co2,
      averageAQI: envData.airQualityIndex,
      totalElevationGain: envData.elevationGain,
      trafficLevel: (envData.trafficCongestion * trafficMult).clamp(0.0, 1.0),
      weatherImpact: envData.weatherImpact,
    );
  }

  double _getVehicleSpeed(String vehicle) {
    switch (vehicle.toLowerCase()) {
      case 'electric car':
      case 'petrol car':
        return 40.0;
      case 'bicycle':
        return 15.0;
      case 'walking':
        return 5.0;
      default:
        return 35.0;
    }
  }

  int _calculateTimeVsBaseline(
    double duration,
    double baselineDistance,
    String vehicleType,
  ) {
    double speed = _getVehicleSpeed(vehicleType);
    double baselineTime = (baselineDistance / speed) * 60;
    if (baselineTime <= 0) return 0;
    double diff = ((duration - baselineTime) / baselineTime * 100);
    return diff.round();
  }

  /// Parse numeric value from potentially mixed types (int, double, String)
  double _parseNumeric(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
