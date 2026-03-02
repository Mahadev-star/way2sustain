// Prediction Service - 5-Day Future Route Prediction
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sustainable_travel_app/config/api_config.dart';
import 'package:latlong2/latlong.dart';

class DayPrediction {
  final int dayOffset;
  final String date;
  final double trafficScore;
  final double aqiScore;
  final double weatherSeverity;
  final double co2Emission;
  final double evAvailability;
  final double sustainabilityScore;
  final bool isHoliday;
  final String holidayName;
  final bool isWeekend;
  final bool peakHour;

  DayPrediction({
    required this.dayOffset,
    required this.date,
    required this.trafficScore,
    required this.aqiScore,
    required this.weatherSeverity,
    required this.co2Emission,
    required this.evAvailability,
    required this.sustainabilityScore,
    required this.isHoliday,
    required this.holidayName,
    required this.isWeekend,
    required this.peakHour,
  });

  factory DayPrediction.fromJson(Map<String, dynamic> json) {
    return DayPrediction(
      dayOffset: json['day_offset'] ?? 0,
      date: json['date'] ?? '',
      trafficScore: (json['traffic_score'] ?? 50).toDouble(),
      aqiScore: (json['aqi_score'] ?? 50).toDouble(),
      weatherSeverity: (json['weather_severity'] ?? 0.1).toDouble(),
      co2Emission: (json['co2_emission'] ?? 0).toDouble(),
      evAvailability: (json['ev_availability'] ?? 0.5).toDouble(),
      sustainabilityScore: (json['sustainability_score'] ?? 50).toDouble(),
      isHoliday: json['is_holiday'] ?? false,
      holidayName: json['holiday_name'] ?? '',
      isWeekend: json['is_weekend'] ?? false,
      peakHour: json['peak_hour'] ?? false,
    );
  }

  String get dayLabel {
    if (dayOffset == 0) return 'Today';
    if (dayOffset == 1) return 'Tomorrow';
    final dateTime = DateTime.tryParse(date);
    if (dateTime != null) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    }
    return 'Day $dayOffset';
  }

  String get shortDate {
    final dateTime = DateTime.tryParse(date);
    if (dateTime != null) {
      return '${dateTime.day}/${dateTime.month}';
    }
    return date.isNotEmpty ? date.substring(5) : '';
  }

  String get trafficLevel {
    if (trafficScore <= 30) return 'Low';
    if (trafficScore <= 60) return 'Moderate';
    if (trafficScore <= 80) return 'High';
    return 'Very High';
  }

  String get aqiLevel {
    if (aqiScore <= 50) return 'Good';
    if (aqiScore <= 100) return 'Moderate';
    if (aqiScore <= 150) return 'Unhealthy for Sensitive';
    if (aqiScore <= 200) return 'Unhealthy';
    return 'Very Unhealthy';
  }

  String get sustainabilityLevel {
    if (sustainabilityScore >= 70) return 'Excellent';
    if (sustainabilityScore >= 50) return 'Good';
    if (sustainabilityScore >= 30) return 'Moderate';
    return 'Poor';
  }
}

class PredictionResult {
  final List<DayPrediction> predictions;
  final double distanceKm;
  final String status;

  PredictionResult({
    required this.predictions,
    required this.distanceKm,
    required this.status,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final predictionsList =
        (json['predictions'] as List?)
            ?.map((p) => DayPrediction.fromJson(p))
            .toList() ??
        [];
    return PredictionResult(
      predictions: predictionsList,
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      status: json['status'] ?? 'unknown',
    );
  }
}

class RouteCost {
  final double totalCost;
  final double trafficCost;
  final double aqiCost;
  final double co2Cost;
  final double distanceCost;
  final double weatherCost;
  final double avgTraffic;
  final double avgAqi;
  final double avgCo2;
  final double avgWeather;
  final double sustainabilityScore;

  RouteCost({
    required this.totalCost,
    required this.trafficCost,
    required this.aqiCost,
    required this.co2Cost,
    required this.distanceCost,
    required this.weatherCost,
    required this.avgTraffic,
    required this.avgAqi,
    required this.avgCo2,
    required this.avgWeather,
    required this.sustainabilityScore,
  });

  factory RouteCost.fromJson(Map<String, dynamic> json) {
    return RouteCost(
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      trafficCost: (json['traffic_cost'] ?? 0).toDouble(),
      aqiCost: (json['aqi_cost'] ?? 0).toDouble(),
      co2Cost: (json['co2_cost'] ?? 0).toDouble(),
      distanceCost: (json['distance_cost'] ?? 0).toDouble(),
      weatherCost: (json['weather_cost'] ?? 0).toDouble(),
      avgTraffic: (json['avg_traffic'] ?? 0).toDouble(),
      avgAqi: (json['avg_aqi'] ?? 0).toDouble(),
      avgCo2: (json['avg_co2'] ?? 0).toDouble(),
      avgWeather: (json['avg_weather'] ?? 0).toDouble(),
      sustainabilityScore: (json['sustainability_score'] ?? 0).toDouble(),
    );
  }
}

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  /// Get predictions for the next N days
  Future<PredictionResult> getPredictions({
    required LatLng start,
    required LatLng end,
    required String vehicleType,
    int numDays = 5,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.backendUrl}/api/predictions');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'start_lat': start.latitude,
              'start_lng': start.longitude,
              'end_lat': end.latitude,
              'end_lng': end.longitude,
              'vehicle_type': vehicleType,
              'num_days': numDays,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PredictionResult.fromJson(data);
      } else {
        debugPrint('Prediction API error: ${response.statusCode}');
        return _getFallbackPredictions(numDays);
      }
    } catch (e) {
      debugPrint('Prediction service error: $e');
      return _getFallbackPredictions(numDays);
    }
  }

  /// Get route predictions with ACO cost calculation
  Future<Map<String, dynamic>> getRoutePredictions({
    required LatLng start,
    required LatLng end,
    required String vehicleType,
    int numDays = 5,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.backendUrl}/api/routes/predict');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'start_lat': start.latitude,
              'start_lng': start.longitude,
              'end_lat': end.latitude,
              'end_lng': end.longitude,
              'vehicle_type': vehicleType,
              'num_days': numDays,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'predictions':
              (data['predictions'] as List?)
                  ?.map((p) => DayPrediction.fromJson(p))
                  .toList() ??
              [],
          'route_costs':
              (data['route_costs'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, RouteCost.fromJson(value)),
              ) ??
              {},
          'distance_km': data['distance_km'] ?? 0.0,
          'status': data['status'] ?? 'unknown',
        };
      } else {
        debugPrint('Route prediction API error: ${response.statusCode}');
        return _getFallbackRoutePredictions(numDays);
      }
    } catch (e) {
      debugPrint('Route prediction service error: $e');
      return _getFallbackRoutePredictions(numDays);
    }
  }

  /// Generate fallback predictions when API is unavailable
  PredictionResult _getFallbackPredictions(int numDays) {
    final now = DateTime.now();
    final predictions = <DayPrediction>[];

    for (int i = 0; i < numDays; i++) {
      final date = now.add(Duration(days: i));
      final isWeekend = date.weekday >= 6;
      final hour = date.hour;
      final isPeakHour =
          (hour >= 8 && hour <= 10) || (hour >= 16 && hour <= 20);

      // Generate realistic fallback values
      double trafficScore = isWeekend ? 35.0 : 55.0;
      if (isPeakHour && !isWeekend) trafficScore += 25;
      trafficScore = trafficScore.clamp(0, 100);

      final aqiScore = 60.0 + (i * 5) + (isWeekend ? -10 : 0);
      final weatherSeverity = 0.2 + (i * 0.05);
      final co2Emission = 50.0 + (trafficScore * 0.3);
      final evAvailability =
          0.6 - (isWeekend ? 0.15 : 0) - (isPeakHour ? 0.1 : 0);
      final sustainabilityScore =
          70.0 - (trafficScore * 0.2) - (aqiScore * 0.1);

      predictions.add(
        DayPrediction(
          dayOffset: i,
          date: date.toIso8601String().split('T')[0],
          trafficScore: trafficScore,
          aqiScore: aqiScore.clamp(20, 300),
          weatherSeverity: weatherSeverity.clamp(0, 1),
          co2Emission: co2Emission,
          evAvailability: evAvailability.clamp(0.1, 1.0),
          sustainabilityScore: sustainabilityScore.clamp(0, 100),
          isHoliday: false,
          holidayName: '',
          isWeekend: isWeekend,
          peakHour: isPeakHour,
        ),
      );
    }

    return PredictionResult(
      predictions: predictions,
      distanceKm: 0,
      status: 'fallback',
    );
  }

  Map<String, dynamic> _getFallbackRoutePredictions(int numDays) {
    final predictionsResult = _getFallbackPredictions(numDays);
    return {
      'predictions': predictionsResult.predictions,
      'route_costs': <String, RouteCost>{},
      'distance_km': 0.0,
      'status': 'fallback',
    };
  }

  /// Get prediction for a specific day offset
  DayPrediction? getPredictionForDay(
    List<DayPrediction> predictions,
    int dayOffset,
  ) {
    try {
      return predictions.firstWhere((p) => p.dayOffset == dayOffset);
    } catch (e) {
      return predictions.isNotEmpty ? predictions.first : null;
    }
  }
}
