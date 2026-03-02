import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sustainable_travel_app/services/route_service.dart';
import 'package:sustainable_travel_app/services/environmental_data_service.dart';
import 'package:sustainable_travel_app/services/prediction_service.dart';
import 'package:sustainable_travel_app/models/route_data.dart';
import 'package:sustainable_travel_app/models/route_option.dart';
import 'package:sustainable_travel_app/route/route_result_page.dart';

class RouteSelectionScreen extends StatefulWidget {
  final String from;
  final String to;
  final LatLng fromLocation;
  final LatLng toLocation;
  final String vehicle;

  const RouteSelectionScreen({
    super.key,
    required this.from,
    required this.to,
    required this.fromLocation,
    required this.toLocation,
    required this.vehicle,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  late final RouteService _routeService;
  late final EnvironmentalDataService _envService;
  late final PredictionService _predictionService;

  List<RouteOption> _routeOptions = [];
  RouteOption? _selectedRoute;
  bool _isLoading = true;
  String? _errorMessage;

  // Map controller
  late final MapController _mapController;
  double _currentZoom = 12.0;
  bool _showSatellite = false;
  bool _isMapReady = false;

  // EV Chargers
  List<Map<String, dynamic>> _evChargers = [];
  bool _loadingChargers = false;

  // Smart recommendations
  String? _recommendationMessage;
  Color _recommendationColor = Colors.blue;

  // Bottom detail panel visibility
  bool _showBottomPanel = false;

  // Date Selection for 5-Day Prediction
  DateTime _selectedDate = DateTime.now();
  bool _showPrediction = false;
  List<DayPrediction> _predictions = [];
  bool _loadingPredictions = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _routeService = RouteService();
    _envService = EnvironmentalDataService();
    _predictionService = PredictionService();
    _fetchRouteOptions();
    _fetchPredictions();
    _checkVehicleRecommendation();
  }

  /// Fetch 5-day predictions for the route
  Future<void> _fetchPredictions() async {
    setState(() => _loadingPredictions = true);
    try {
      final result = await _predictionService.getPredictions(
        start: widget.fromLocation,
        end: widget.toLocation,
        vehicleType: widget.vehicle,
        numDays: 5,
      );
      setState(() {
        _predictions = result.predictions;
        _loadingPredictions = false;
      });
    } catch (e) {
      debugPrint('Error fetching predictions: $e');
      setState(() => _loadingPredictions = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Check if vehicle choice is appropriate for distance
  void _checkVehicleRecommendation() {
    double distanceKm =
        const Distance().distance(widget.fromLocation, widget.toLocation) /
        1000;

    String recommendation = '';
    Color color = Colors.blue;

    if (widget.vehicle == 'Walking') {
      if (distanceKm > 5) {
        recommendation =
            '⚠️ ${distanceKm.toStringAsFixed(1)}km walk takes ~${(distanceKm / 5 * 60).round()}min. Consider cycling.';
        color = Colors.orange;
      } else if (distanceKm > 3) {
        recommendation =
            '🚶 Good walk! ${distanceKm.toStringAsFixed(1)}km, ~${(distanceKm / 5 * 60).round()}min, burns ${(distanceKm * 65).round()} cal.';
        color = Colors.green;
      } else {
        recommendation = '👟 Short pleasant walk! Great for health.';
        color = Colors.green;
      }
    } else if (widget.vehicle == 'Bicycle') {
      if (distanceKm > 20) {
        recommendation =
            '⚠️ Long cycle ${distanceKm.toStringAsFixed(1)}km takes ~${(distanceKm / 15 * 60).round()}min. Bring repair kit!';
        color = Colors.orange;
      } else if (distanceKm > 10) {
        recommendation =
            '🚴 Great cycle! ${distanceKm.toStringAsFixed(1)}km, ~${(distanceKm / 15 * 60).round()}min, burns ${(distanceKm * 30).round()} cal.';
        color = Colors.green;
      } else {
        recommendation = '🚲 Perfect distance for cycling!';
        color = Colors.green;
      }
    } else if (widget.vehicle == 'Electric Car') {
      if (distanceKm < 3) {
        recommendation =
            '💡 Short trip (${distanceKm.toStringAsFixed(1)}km). Walking/cycling saves energy!';
        color = Colors.amber;
      } else {
        recommendation = '⚡ EV selected. Check charging stations.';
        color = Colors.lightGreen;
      }
    } else if (widget.vehicle == 'Petrol Car') {
      if (distanceKm < 2) {
        recommendation =
            '💡 Short trip - consider walking/cycling to save fuel!';
        color = Colors.amber;
      }
    }

    setState(() {
      _recommendationMessage = recommendation;
      _recommendationColor = color;
    });
  }

  /// Validate and filter route points to remove invalid coordinates
  List<LatLng> _validateAndFilterPoints(List<LatLng> points) {
    if (points.isEmpty) return [];
    const double maxJumpDistance = 50000;
    const double minLat = -90.0;
    const double maxLat = 90.0;
    const double minLng = -180.0;
    const double maxLng = 180.0;
    final validPoints = <LatLng>[];
    LatLng? previousValidPoint;
    for (final point in points) {
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < minLat ||
          point.latitude > maxLat ||
          point.longitude < minLng ||
          point.longitude > maxLng) {
        continue;
      }
      if (previousValidPoint != null) {
        final distance = const Distance().distance(previousValidPoint, point);
        if (distance > maxJumpDistance) continue;
      }
      validPoints.add(point);
      previousValidPoint = point;
    }
    if (validPoints.length < points.length * 0.5) return points;
    return validPoints;
  }

  /// Sort routes to display in correct order: Eco → Balanced → Quick
  List<RouteOption> _sortRoutes(List<RouteOption> routes) {
    return List.from(routes)..sort((a, b) {
      if (a.type.contains('ECO CHAMPION') && !b.type.contains('ECO CHAMPION'))
        return -1;
      if (!a.type.contains('ECO CHAMPION') && b.type.contains('ECO CHAMPION'))
        return 1;
      if (a.type.contains('BALANCED') && b.type.contains('QUICKEST')) return -1;
      if (a.type.contains('QUICKEST') && b.type.contains('BALANCED')) return 1;
      return 0;
    });
  }

  /// Fetch 3 different route options from ACO
  Future<void> _fetchRouteOptions() async {
    try {
      setState(() => _isLoading = true);
      _routeService.setSelectedDate(_selectedDate);
      final options = await _routeService.findRouteOptions(
        start: widget.fromLocation,
        end: widget.toLocation,
        vehicleType: widget.vehicle,
        onProgress: (progress) {
          debugPrint(
            '📊 Route calculation progress: ${(progress * 100).round()}%',
          );
        },
      );
      if (options.isNotEmpty && mounted) {
        // Validate and filter points for all routes
        final validatedOptions = options.map((option) {
          final validatedPoints = _validateAndFilterPoints(
            option.routeData.points,
          );
          final newRouteData = RouteData(
            points: validatedPoints,
            distance: option.routeData.distance,
            duration: option.routeData.duration,
            instructions: option.routeData.instructions,
            co2Emissions: option.routeData.co2Emissions,
            averageAQI: option.routeData.averageAQI,
            totalElevationGain: option.routeData.totalElevationGain,
            trafficLevel: option.routeData.trafficLevel,
            weatherImpact: option.routeData.weatherImpact,
          );
          return RouteOption(
            type: option.type,
            description: option.description,
            icon: option.icon,
            routeData: newRouteData,
            ecoPoints: option.ecoPoints,
            timeVsBaseline: option.timeVsBaseline,
            co2Savings: option.co2Savings,
            averageAQI: option.averageAQI,
            trafficLevel: option.trafficLevel,
          );
        }).toList();
        // Sort routes: Eco → Balanced → Quick
        final sortedOptions = _sortRoutes(validatedOptions);
        setState(() {
          _routeOptions = sortedOptions;
          _selectedRoute = sortedOptions.first;
          _isLoading = false;
        });
        if (widget.vehicle == 'Electric Car') {
          _loadEVChargers();
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _isMapReady) {
            _centerMapOnRoute();
          }
        });
      } else {
        setState(() {
          _errorMessage = 'No routes found. Please try different locations.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error finding routes: $e';
        _isLoading = false;
      });
    }
  }

  /// Load EV charging stations near the route
  Future<void> _loadEVChargers() async {
    if (_selectedRoute == null) return;

    setState(() => _loadingChargers = true);

    try {
      final routePoints = _selectedRoute!.routeData.points;

      // Sample points along route (every 2km)
      List<LatLng> samplePoints = [];
      double interval = 2000;
      double accumulated = 0;

      for (int i = 0; i < routePoints.length - 1; i++) {
        final from = routePoints[i];
        final to = routePoints[i + 1];
        final segmentDist = const Distance().distance(from, to);

        if (accumulated + segmentDist > interval) {
          double ratio = (interval - accumulated) / segmentDist;
          double lat = from.latitude + (to.latitude - from.latitude) * ratio;
          double lng = from.longitude + (to.longitude - from.longitude) * ratio;
          samplePoints.add(LatLng(lat, lng));
          accumulated = 0;
        } else {
          accumulated += segmentDist;
        }
      }

      samplePoints.add(widget.fromLocation);
      samplePoints.add(widget.toLocation);

      Set<String> chargerIds = {};
      List<Map<String, dynamic>> allChargers = [];

      for (var point in samplePoints) {
        final chargers = await _envService.findEVChargersORS(point, 2000);
        for (var charger in chargers) {
          if (!chargerIds.contains(charger['id'])) {
            chargerIds.add(charger['id']);

            double minDist = double.infinity;
            for (var routePoint in routePoints) {
              double dist = const Distance().distance(
                charger['location'],
                routePoint,
              );
              if (dist < minDist) minDist = dist;
            }

            charger['distanceFromRoute'] = minDist;
            allChargers.add(charger);
          }
        }
      }

      allChargers.sort(
        (a, b) => a['distanceFromRoute'].compareTo(b['distanceFromRoute']),
      );

      setState(() {
        _evChargers = allChargers.take(10).toList();
        _loadingChargers = false;
      });

      debugPrint('✅ Found ${_evChargers.length} EV charging stations');
    } catch (e) {
      debugPrint('❌ Error loading EV chargers: $e');
      setState(() => _loadingChargers = false);
    }
  }

  /// Center map on selected route only
  void _centerMapOnRoute() {
    if (!_isMapReady || _routeOptions.isEmpty) return;

    try {
      // Focus on selected route only
      final routeToUse = _selectedRoute ?? _routeOptions.first;
      final points = routeToUse.routeData.points;

      if (points.isEmpty) {
        _centerOnDefault();
        return;
      }

      final validPoints = points
          .where(
            (p) =>
                p.latitude.isFinite &&
                p.longitude.isFinite &&
                p.latitude > -90 &&
                p.latitude < 90 &&
                p.longitude > -180 &&
                p.longitude < 180,
          )
          .toList();

      if (validPoints.isEmpty) {
        _centerOnDefault();
        return;
      }

      double minLat = validPoints.map((p) => p.latitude).reduce(math.min);
      double maxLat = validPoints.map((p) => p.latitude).reduce(math.max);
      double minLng = validPoints.map((p) => p.longitude).reduce(math.min);
      double maxLng = validPoints.map((p) => p.longitude).reduce(math.max);

      double latPadding = (maxLat - minLat).abs();
      double lngPadding = (maxLng - minLng).abs();

      const minPadding = 0.001;
      if (latPadding < minPadding) latPadding = minPadding;
      if (lngPadding < minPadding) lngPadding = minPadding;

      latPadding = latPadding * 0.15 + minPadding;
      lngPadding = lngPadding * 0.15 + minPadding;

      latPadding = latPadding.clamp(0.01, 2.0);
      lngPadding = lngPadding.clamp(0.01, 2.0);

      final southWest = LatLng(
        (minLat - latPadding).clamp(-89.0, 89.0),
        (minLng - lngPadding).clamp(-179.0, 179.0),
      );
      final northEast = LatLng(
        (maxLat + latPadding).clamp(-89.0, 89.0),
        (maxLng + lngPadding).clamp(-179.0, 179.0),
      );

      if (southWest.latitude >= northEast.latitude ||
          southWest.longitude >= northEast.longitude) {
        _centerOnDefault();
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(southWest, northEast),
          padding: const EdgeInsets.all(80),
        ),
      );
    } catch (e) {
      debugPrint('Error centering map: $e');
      _centerOnDefault();
    }
  }

  /// Center map on default location
  void _centerOnDefault() {
    try {
      final centerLat =
          (widget.fromLocation.latitude + widget.toLocation.latitude) / 2;
      final centerLng =
          (widget.fromLocation.longitude + widget.toLocation.longitude) / 2;

      if (!centerLat.isFinite || !centerLng.isFinite) {
        _mapController.move(widget.fromLocation, _currentZoom);
        return;
      }

      _mapController.move(
        LatLng(centerLat.clamp(-89.0, 89.0), centerLng.clamp(-179.0, 179.0)),
        _currentZoom,
      );
    } catch (e) {
      if (widget.fromLocation.latitude.isFinite &&
          widget.fromLocation.longitude.isFinite) {
        _mapController.move(widget.fromLocation, _currentZoom);
      }
    }
  }

  /// Handle route selection
  void _onRouteSelected(int index) {
    setState(() {
      _selectedRoute = _routeOptions[index];
      _showBottomPanel = true;
    });

    if (widget.vehicle == 'Electric Car') {
      _loadEVChargers();
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isMapReady) {
        _centerMapOnRoute();
      }
    });
  }

  /// Build metric item
  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build indicator item
  Widget _buildIndicatorItem({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 1),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build route option card
  Widget _buildRouteOptionCard(RouteOption option, int index) {
    final isSelected = _selectedRoute == option;
    final distanceKm = option.routeData.distance;
    final durationMin = option.routeData.duration;
    final co2Saved = option.co2Savings.round();
    final ecoScore = option.ecoPoints;
    final trafficLevel = (option.routeData.trafficLevel * 100).round();
    final aqiValue = option.routeData.averageAQI.round();
    final elevationGain = option.routeData.totalElevationGain.round();
    final treesEquivalent = (co2Saved / 22000).abs().ceil();

    final showPoints = option.type != 'QUICKEST';
    final points = showPoints ? option.ecoPoints : 0;

    return GestureDetector(
      onTap: () => _onRouteSelected(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? option.cardColor.withAlpha(26)
              : const Color(0xFF1A1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: option.cardColor.withAlpha(isSelected ? 255 : 128),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: option.cardColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    option.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: option.cardColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        option.description,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: option.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showPoints ? Icons.eco : Icons.timer,
                        color: Colors.white,
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        showPoints ? '$points pts' : 'Fast',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetricItem(
                  icon: Icons.straighten,
                  value: '${distanceKm.toStringAsFixed(1)}km',
                  color: Colors.blue,
                ),
                _buildMetricItem(
                  icon: Icons.timer,
                  value: '${durationMin.round()}min',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIndicatorItem(
                    icon: Icons.co2,
                    value: '${co2Saved}g',
                    color: Colors.brown,
                  ),
                  _buildIndicatorItem(
                    icon: Icons.air,
                    value: '$aqiValue',
                    color: _getAQIColor(option.routeData.averageAQI),
                  ),
                  _buildIndicatorItem(
                    icon: Icons.traffic,
                    value: '$trafficLevel%',
                    color: _getTrafficColor(option.routeData.trafficLevel),
                  ),
                  _buildIndicatorItem(
                    icon: Icons.terrain,
                    value: '${elevationGain}m',
                    color: Colors.brown,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (option.type.contains('ECO CHAMPION') ||
                option.type.contains('ECO'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.green, size: 10),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '$treesEquivalent tree${treesEquivalent > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (option.type.contains('BALANCED'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.withAlpha(77)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.balance, color: Colors.blue, size: 10),
                    SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '⚖️ Balanced',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (option.type.contains('QUICKEST') ||
                option.type.contains('Fast'))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: option.cardColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: option.cardColor.withAlpha(77)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.speed, color: option.cardColor, size: 10),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '⏱️ Fastest - 0 pts',
                        style: TextStyle(
                          color: option.cardColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAQIColor(double aqi) {
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.orange;
    if (aqi <= 150) return Colors.red;
    if (aqi <= 200) return Colors.purple;
    return Colors.brown;
  }

  Color _getTrafficColor(double traffic) {
    if (traffic < 0.3) return Colors.green;
    if (traffic < 0.6) return Colors.orange;
    return Colors.red;
  }

  /// Build bottom detail panel
  Widget _buildBottomDetailPanel() {
    if (_selectedRoute == null || !_showBottomPanel) {
      return const SizedBox.shrink();
    }

    final route = _selectedRoute!;
    final routeColor = route.cardColor;
    final distanceKm = route.routeData.distance;
    final durationMin = route.routeData.duration;
    final co2Emissions = route.routeData.co2Emissions.round();
    final aqiValue = route.routeData.averageAQI.round();
    final trafficLevel = (route.routeData.trafficLevel * 100).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: routeColor.withAlpha(128), width: 2),
        boxShadow: [
          BoxShadow(
            color: routeColor.withAlpha(51),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      route.type.contains('ECO CHAMPION')
                          ? Icons.eco
                          : route.type.contains('BALANCED')
                          ? Icons.balance
                          : Icons.speed,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      route.routeTypeDisplay,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () => setState(() => _showBottomPanel = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${distanceKm.toStringAsFixed(1)} km',
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.timer,
                  label: 'Time',
                  value: '${durationMin.round()} min',
                  color: Colors.orange,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.co2,
                  label: 'Emission',
                  value: '${co2Emissions}g',
                  color: Colors.brown,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.air,
                  label: 'Air Quality',
                  value: '$aqiValue AQI',
                  color: _getAQIColor(route.routeData.averageAQI),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.traffic,
                  label: 'Traffic',
                  value: '$trafficLevel%',
                  color: _getTrafficColor(route.routeData.trafficLevel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0F),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF43A047),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Finding optimal routes...',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Row(
              children: [
                // LEFT PANEL
                Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  color: const Color(0xFF151717),
                  child: Column(
                    children: [
                      // Header with Date Selection
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F1F),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade800),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getVehicleIcon(),
                                  color: const Color(0xFF43A047),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.vehicle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${widget.from} → ${widget.to}',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Date Selection Button
                            GestureDetector(
                              onTap: () => _showDatePicker(refreshRoutes: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2F2F),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF43A047,
                                    ).withAlpha(128),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF43A047),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getDateLabel(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF43A047),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Recommendation banner
                      if (_recommendationMessage != null)
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _recommendationColor.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _recommendationColor.withAlpha(77),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: _recommendationColor,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _recommendationMessage!,
                                  style: TextStyle(
                                    color: _recommendationColor,
                                    fontSize: 9,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 5-Day Prediction Panel
                      if (_predictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F1F),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF43A047).withAlpha(77),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_graph,
                                    color: Color(0xFF43A047),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '5-Day Forecast',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_loadingPredictions)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1,
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _showPrediction =
                                              !_showPrediction,
                                        );
                                      },
                                      child: Icon(
                                        _showPrediction
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: const Color(0xFF43A047),
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                              if (_showPrediction) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 70,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _predictions.length,
                                    itemBuilder: (context, index) {
                                      final prediction = _predictions[index];
                                      return _buildPredictionCard(prediction);
                                    },
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildQuickStat(
                                      'Traffic',
                                      _getTrafficLevel(
                                        _predictions[0].trafficScore,
                                      ),
                                      _getTrafficColor(
                                        _predictions[0].trafficScore / 100,
                                      ),
                                    ),
                                    _buildQuickStat(
                                      'AQI',
                                      _getAqiLevel(_predictions[0].aqiScore),
                                      _getAQIColor(_predictions[0].aqiScore),
                                    ),
                                    _buildQuickStat(
                                      'Sust.',
                                      '${_predictions[0].sustainabilityScore.round()}%',
                                      _getSustainabilityColor(
                                        _predictions[0].sustainabilityScore,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Route options - sorted order
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _routeOptions.length,
                          itemBuilder: (context, index) =>
                              _buildRouteOptionCard(
                                _routeOptions[index],
                                index,
                              ),
                        ),
                      ),

                      // EV Chargers
                      if (widget.vehicle == 'Electric Car' &&
                          _evChargers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F1F),
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.ev_station,
                                    color: Color(0xFF43A047),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'EV Chargers',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_loadingChargers)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_evChargers.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _evChargers.length,
                                  itemBuilder: (context, index) {
                                    final charger = _evChargers[index];
                                    return Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[900],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            charger['name'].length > 10
                                                ? '${charger['name'].substring(0, 10)}...'
                                                : charger['name'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 7,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${(charger['distanceFromRoute'] / 1000).toStringAsFixed(1)}km',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Select button
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: _selectedRoute == null
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RouteResultPage(
                                          from: widget.from,
                                          to: widget.to,
                                          vehicle: widget.vehicle,
                                          ecoPoints: _selectedRoute!.ecoPoints,
                                          fromLocation: widget.fromLocation,
                                          toLocation: widget.toLocation,
                                          routeData: _selectedRoute!.routeData,
                                          routeType: _selectedRoute!.type,
                                          routeColor: _selectedRoute!.cardColor,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedRoute?.cardColor ??
                                  const Color(0xFF43A047),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              'Select',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // RIGHT PANEL - Map
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        key: ValueKey(_selectedRoute?.routeData.hashCode ?? 0),
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(
                            (widget.fromLocation.latitude +
                                    widget.toLocation.latitude) /
                                2,
                            (widget.fromLocation.longitude +
                                    widget.toLocation.longitude) /
                                2,
                          ),
                          initialZoom: _currentZoom,
                          onMapReady: () {
                            setState(() => _isMapReady = true);
                            if (_selectedRoute != null) _centerMapOnRoute();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _showSatellite
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.sustainable_travel_app',
                          ),
                          // Show only selected route with highlighting
                          if (_routeOptions.isNotEmpty)
                            PolylineLayer(
                              polylines: _routeOptions.map((route) {
                                final isSelected = _selectedRoute == route;
                                return Polyline(
                                  points: route.routeData.points,
                                  color: isSelected
                                      ? route.cardColor
                                      : route.cardColor.withAlpha(77),
                                  strokeWidth: isSelected ? 8.0 : 2.0,
                                  isDotted: !isSelected,
                                );
                              }).toList(),
                            ),
                          if (_evChargers.isNotEmpty &&
                              widget.vehicle == 'Electric Car')
                            MarkerLayer(
                              markers: _evChargers
                                  .map(
                                    (charger) => Marker(
                                      point: charger['location'],
                                      width: 20,
                                      height: 20,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showChargerDetails(charger),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.ev_station,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.fromLocation,
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF43A047),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                              Marker(
                                point: widget.toLocation,
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Column(
                          children: [
                            _buildMapButton(Icons.add, () {
                              setState(
                                () => _currentZoom = (_currentZoom + 1).clamp(
                                  5.0,
                                  18.0,
                                ),
                              );
                              _mapController.move(
                                _mapController.camera.center,
                                _currentZoom,
                              );
                            }),
                            const SizedBox(height: 4),
                            _buildMapButton(Icons.remove, () {
                              setState(
                                () => _currentZoom = (_currentZoom - 1).clamp(
                                  5.0,
                                  18.0,
                                ),
                              );
                              _mapController.move(
                                _mapController.camera.center,
                                _currentZoom,
                              );
                            }),
                            const SizedBox(height: 4),
                            _buildMapButton(
                              _showSatellite ? Icons.map : Icons.satellite,
                              () => setState(
                                () => _showSatellite = !_showSatellite,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildMapButton(
                              Icons.center_focus_strong,
                              _centerMapOnRoute,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomDetailPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 4),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF43A047), size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showChargerDetails(Map<String, dynamic> charger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1F),
        title: Text(
          charger['name'],
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator: ${charger['operator']}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              'Distance: ${(charger['distanceFromRoute'] / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            if (charger['capacity'] != 'Unknown')
              Text(
                'Capacity: ${charger['capacity']}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF43A047),
            ),
            child: const Text('Close', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  IconData _getVehicleIcon() {
    switch (widget.vehicle) {
      case 'Electric Car':
        return Icons.electric_car;
      case 'Petrol Car':
        return Icons.directions_car;
      case 'Bicycle':
        return Icons.directions_bike;
      case 'Walking':
        return Icons.directions_walk;
      default:
        return Icons.directions;
    }
  }

  String _getDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final difference = selectedDay.difference(today).inDays;
    if (difference == 0)
      return 'Today';
    else if (difference == 1)
      return 'Tomorrow';
    else
      return '${_selectedDate.day}/${_selectedDate.month}';
  }

  Future<void> _showDatePicker({bool refreshRoutes = false}) async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 4));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: maxDate,
      helpText: 'Select travel date (up to 5 days ahead)',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _routeService.setSelectedDate(picked);
      if (refreshRoutes) {
        _fetchRouteOptions();
        _fetchPredictions();
      }
    }
  }

  /// Build prediction card for a single day
  Widget _buildPredictionCard(DayPrediction prediction) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F2F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getSustainabilityColor(
            prediction.sustainabilityScore,
          ).withAlpha(128),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prediction.dayLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            prediction.shortDate,
            style: TextStyle(color: Colors.grey[400], fontSize: 7),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.traffic,
                color: _getTrafficColor(prediction.trafficScore / 100),
                size: 10,
              ),
              const SizedBox(width: 2),
              Text(
                '${prediction.trafficScore.round()}%',
                style: TextStyle(
                  color: _getTrafficColor(prediction.trafficScore / 100),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.air,
                color: _getAQIColor(prediction.aqiScore),
                size: 10,
              ),
              const SizedBox(width: 2),
              Text(
                '${prediction.aqiScore.round()}',
                style: TextStyle(
                  color: _getAQIColor(prediction.aqiScore),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${prediction.sustainabilityScore.round()}%',
            style: TextStyle(
              color: _getSustainabilityColor(prediction.sustainabilityScore),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 8)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getTrafficLevel(double score) {
    if (score <= 30) return 'Low';
    if (score <= 60) return 'Med';
    if (score <= 80) return 'High';
    return 'V.High';
  }

  String _getAqiLevel(double score) {
    if (score <= 50) return 'Good';
    if (score <= 100) return 'Mod';
    if (score <= 150) return 'Unh.Sens';
    return 'Unhealthy';
  }

  Color _getSustainabilityColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 50) return Colors.lightGreen;
    if (score >= 30) return Colors.orange;
    return Colors.red;
  }
}
