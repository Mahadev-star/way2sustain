/// Eco Points Calculator - Weighted sustainability score computation
///
/// Calculation Steps:
/// 1. Define Baseline Route (QUICKEST route)
/// 2. CO2 Savings Score (Weight 40%)
/// 3. Air Quality Score (Weight 20%)
/// 4. Traffic Efficiency Score (Weight 15%)
/// 5. Time Penalty Adjustment (Weight 10%)
/// 6. Transport Mode Multiplier (Weight 15%)
/// 7. Final Calculation with clamping

class EcoPointsCalculator {
  // Weight constants
  static const double co2Weight = 0.40; // 40%
  static const double aqiWeight = 0.20; // 20%
  static const double trafficWeight = 0.15; // 15%
  static const double timePenaltyWeight = 0.10; // 10%

  // Constants for calculations
  static const double maxAqi = 300.0; // AQI threshold for scoring
  static const double timePenaltyThreshold = 20.0; // minutes
  static const double timePenaltyValue = 5.0; // penalty points

  // Transport mode multipliers
  static const Map<String, double> transportMultipliers = {
    'walking': 1.5,
    'bicycle': 1.4,
    'cycling': 1.4,
    'electric car': 1.2,
    'electric': 1.2,
    'hybrid car': 1.1,
    'hybrid': 1.1,
    'petrol car': 1.0,
    'petrol': 1.0,
    'diesel car': 1.0,
    'diesel': 1.0,
  };

  // CO2 emissions baseline (grams per km)
  static const Map<String, double> baseEmissions = {
    'walking': 0.0,
    'bicycle': 0.0,
    'cycling': 0.0,
    'electric car': 50.0,
    'electric': 50.0,
    'hybrid car': 80.0,
    'hybrid': 80.0,
    'petrol car': 120.0,
    'petrol': 120.0,
    'diesel car': 140.0,
    'diesel': 140.0,
  };

  /// Calculate Eco Points for a list of routes
  /// Returns a list of routes with calculated ecoPoints
  static List<CalculatedRoute> calculateAllRoutes(List<RouteInput> routes) {
    if (routes.isEmpty) return [];

    // Step 1: Find baseline (QUICKEST route)
    final baseline = _findBaselineRoute(routes);
    if (baseline == null) return [];

    final baselineCO2 = baseline.co2Emissions;

    // Calculate eco points for each route
    final results = <CalculatedRoute>[];

    for (final route in routes) {
      final calcResult = calculateSingleRoute(
        route: route,
        baselineCO2: baselineCO2,
        baselineDuration: baseline.duration,
      );
      results.add(calcResult);
    }

    return results;
  }

  /// Calculate Eco Points for a single route
  static CalculatedRoute calculateSingleRoute({
    required RouteInput route,
    required double baselineCO2,
    required double baselineDuration,
  }) {
    // Step 2: CO2 Savings Score (40%)
    final co2Savings = baselineCO2 - route.co2Emissions;
    double co2Score = 0.0;
    if (baselineCO2 > 0) {
      co2Score = (co2Savings / baselineCO2) * (co2Weight * 100);
    }
    co2Score = co2Score.clamp(0.0, co2Weight * 100);

    // Step 3: Air Quality Score (20%)
    double aqiScore = (1.0 - (route.averageAQI / maxAqi)) * (aqiWeight * 100);
    aqiScore = aqiScore.clamp(0.0, aqiWeight * 100);

    // Step 4: Traffic Efficiency Score (15%)
    double trafficScore = (1.0 - route.trafficLevel) * (trafficWeight * 100);
    trafficScore = trafficScore.clamp(0.0, trafficWeight * 100);

    // Step 5: Time Penalty Adjustment (10%)
    double timePenalty = 0.0;
    if (route.timeVsBaseline > timePenaltyThreshold) {
      timePenalty = -timePenaltyValue;
    }

    // Step 6: Transport Mode Multiplier
    final multiplier = _getTransportMultiplier(route.vehicleType);

    // Step 7: Final Calculation
    double baseScore = co2Score + aqiScore + trafficScore + timePenalty;
    double ecoPoints = baseScore * multiplier;

    // Clamp between 5 and 100
    ecoPoints = ecoPoints.clamp(5.0, 100.0);

    // Determine badge text
    final badgeText = _getBadgeText(ecoPoints);

    return CalculatedRoute(
      routeId: route.routeId,
      ecoPoints: ecoPoints.round(),
      co2Score: co2Score,
      aqiScore: aqiScore,
      trafficScore: trafficScore,
      timePenalty: timePenalty,
      multiplier: multiplier,
      co2Savings: co2Savings,
      badgeText: badgeText,
    );
  }

  /// Find the baseline route (QUICKEST)
  static RouteInput? _findBaselineRoute(List<RouteInput> routes) {
    if (routes.isEmpty) return null;

    // Find route with type containing 'QUICKEST' or 'FAST'
    RouteInput? quickestRoute;
    for (final route in routes) {
      final typeLower = route.routeType.toLowerCase();
      if (typeLower.contains('quickest') || typeLower.contains('fast')) {
        quickestRoute = route;
        break;
      }
    }

    // If no quickest found, use the one with shortest duration
    quickestRoute ??= routes.reduce((a, b) => a.duration < b.duration ? a : b);

    return quickestRoute;
  }

  /// Get transport mode multiplier
  static double _getTransportMultiplier(String vehicleType) {
    final key = vehicleType.toLowerCase();
    return transportMultipliers[key] ?? 1.0;
  }

  /// Get badge text based on eco points
  static String _getBadgeText(double ecoPoints) {
    if (ecoPoints >= 70) {
      return '🌱 Most Eco-Friendly';
    } else if (ecoPoints >= 40) {
      return '⚖️ Best Balance';
    } else {
      return '⏱️ Fastest Route';
    }
  }

  /// Get CO2 emissions for a vehicle type and distance
  static double calculateCO2Emissions(String vehicleType, double distanceKm) {
    final baseEmission = baseEmissions[vehicleType.toLowerCase()] ?? 120.0;
    return baseEmission * distanceKm;
  }

  /// Calculate baseline CO2 (quickest route emissions)
  static double calculateBaselineCO2(String vehicleType, double distanceKm) {
    // Use petrol/diesel as baseline since it's the most common
    final baseEmission = baseEmissions[vehicleType.toLowerCase()] ?? 120.0;
    return baseEmission * distanceKm;
  }
}

/// Input data for route calculation
class RouteInput {
  final String routeId;
  final String routeType;
  final double distance; // km
  final double duration; // minutes
  final double co2Emissions; // grams
  final double averageAQI; // 0-500
  final double trafficLevel; // 0-1
  final double timeVsBaseline; // minutes difference from baseline
  final String vehicleType;

  const RouteInput({
    required this.routeId,
    required this.routeType,
    required this.distance,
    required this.duration,
    required this.co2Emissions,
    required this.averageAQI,
    required this.trafficLevel,
    required this.timeVsBaseline,
    required this.vehicleType,
  });
}

/// Result of eco points calculation
class CalculatedRoute {
  final String routeId;
  final int ecoPoints;
  final double co2Score;
  final double aqiScore;
  final double trafficScore;
  final double timePenalty;
  final double multiplier;
  final double co2Savings;
  final String badgeText;

  const CalculatedRoute({
    required this.routeId,
    required this.ecoPoints,
    required this.co2Score,
    required this.aqiScore,
    required this.trafficScore,
    required this.timePenalty,
    required this.multiplier,
    required this.co2Savings,
    required this.badgeText,
  });

  @override
  String toString() {
    return 'CalculatedRoute(ecoPoints: $ecoPoints, co2Score: ${co2Score.toStringAsFixed(1)}, '
        'aqiScore: ${aqiScore.toStringAsFixed(1)}, trafficScore: ${trafficScore.toStringAsFixed(1)}, '
        'timePenalty: ${timePenalty.toStringAsFixed(1)}, multiplier: $multiplier)';
  }
}
