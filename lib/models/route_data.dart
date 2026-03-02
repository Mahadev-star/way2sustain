import 'package:latlong2/latlong.dart';

/// Real-time environmental factors for route calculation
class RealTimeFactors {
  final double trafficCongestion; // 0-1
  final double airQualityIndex; // 0-500
  final double co2Emissions; // g/km
  final bool hasEVCharger;
  final double weatherImpact; // 0-1
  final double elevationGain; // meters
  final DateTime timestamp;

  RealTimeFactors({
    required this.trafficCongestion,
    required this.airQualityIndex,
    required this.co2Emissions,
    required this.hasEVCharger,
    required this.weatherImpact,
    required this.elevationGain,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isStale => DateTime.now().difference(timestamp).inMinutes > 15;

  static RealTimeFactors fallback(String vehicleType) {
    return RealTimeFactors(
      trafficCongestion: 0.3,
      airQualityIndex: 50.0,
      co2Emissions: _getBaseEmissions(vehicleType),
      hasEVCharger: false,
      weatherImpact: 0.1,
      elevationGain: 0.0,
    );
  }

  static double _getBaseEmissions(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'electric car':
        return 50.0;
      case 'hybrid car':
        return 80.0;
      case 'diesel car':
        return 140.0;
      case 'petrol car':
      default:
        return 120.0;
    }
  }
}

class RouteData {
  final List<LatLng> points;
  final double distance; // in km
  final double duration; // in minutes
  final List<RouteInstruction> instructions;
  final double co2Emissions; // in grams
  final double averageAQI; // 0-500
  final double totalElevationGain; // in meters
  final double trafficLevel; // 0-1
  final double weatherImpact; // 0-1
  final DateTime timestamp;
  final Map<String, dynamic> rawApiData; // Store API responses for reference

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    required this.instructions,
    required this.co2Emissions,
    required this.averageAQI,
    required this.totalElevationGain,
    required this.trafficLevel,
    required this.weatherImpact,
    DateTime? timestamp,
    this.rawApiData = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  // Validate that data is within reasonable ranges
  bool get isValid {
    if (points.isEmpty) return false;
    if (distance <= 0) return false;
    if (duration <= 0) return false;
    if (co2Emissions < 0) return false;
    if (averageAQI < 0 || averageAQI > 500) return false;
    if (trafficLevel < 0 || trafficLevel > 1) return false;
    if (weatherImpact < 0 || weatherImpact > 1) return false;
    return true;
  }

  // Check if data is fresh (less than 15 minutes old)
  bool get isFresh => DateTime.now().difference(timestamp).inMinutes < 15;

  // Calculate trees equivalent for CO2 savings
  int get treesEquivalent {
    // Average tree absorbs ~22kg CO2 per year
    return (co2Emissions / 22000).ceil();
  }

  // Get health recommendation based on AQI
  String get healthRecommendation {
    if (averageAQI <= 50) {
      return 'Good air quality - perfect for outdoor travel';
    } else if (averageAQI <= 100) {
      return 'Moderate air quality - sensitive individuals should take precautions';
    } else if (averageAQI <= 150) {
      return 'Unhealthy for sensitive groups - consider mask if walking/cycling';
    } else if (averageAQI <= 200) {
      return 'Unhealthy - limit outdoor exposure';
    } else {
      return 'Very unhealthy - avoid outdoor travel if possible';
    }
  }

  // Get CO2 savings compared to baseline petrol car
  double get co2Savings {
    double baselineCO2 = (distance * 1000) * 0.12; // 120g/km baseline
    return baselineCO2 - co2Emissions;
  }
}

class RouteInstruction {
  final double distance; // in meters
  final double duration; // in seconds
  final String instruction;
  final String type; // 'turn', 'continue', 'segment'
  final String modifier; // 'left', 'right', 'straight'
  final LatLng location;
  final double trafficCongestion; // 0-1
  final double airQualityIndex; // 0-500
  final bool hasEVCharger;
  final double weatherImpact; // 0-1
  final double elevationGain; // in meters

  RouteInstruction({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.type,
    required this.modifier,
    required this.location,
    this.trafficCongestion = 0.3,
    this.airQualityIndex = 50,
    this.hasEVCharger = false,
    this.weatherImpact = 0.1,
    this.elevationGain = 0.0,
  });

  // Get icon based on instruction type
  String get icon {
    if (type == 'turn') {
      if (modifier == 'left') return '⬅️';
      if (modifier == 'right') return '➡️';
      if (modifier == 'straight') return '⬆️';
    }
    return '⬆️';
  }

  // Get color based on traffic
  String get trafficColor {
    if (trafficCongestion < 0.3) return '🟢';
    if (trafficCongestion < 0.6) return '🟡';
    return '🔴';
  }
}
