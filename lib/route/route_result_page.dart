import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import 'package:sustainable_travel_app/models/route_data.dart';
import 'package:sustainable_travel_app/services/environmental_data_service.dart';
import 'package:sustainable_travel_app/route/journey_tracking_screen.dart';

class RouteResultPage extends StatefulWidget {
  final String from;
  final String to;
  final String vehicle;
  final int ecoPoints;
  final LatLng fromLocation;
  final LatLng toLocation;
  final RouteData routeData;
  final String routeType;
  final Color routeColor;

  const RouteResultPage({
    super.key,
    required this.from,
    required this.to,
    required this.vehicle,
    required this.ecoPoints,
    required this.fromLocation,
    required this.toLocation,
    required this.routeData,
    required this.routeType,
    required this.routeColor,
  });

  @override
  State<RouteResultPage> createState() => _RouteResultPageState();
}

class _RouteResultPageState extends State<RouteResultPage> {
  static const Color brandGreen = Color(0xFF43A047);
  static const Color backgroundColor = Color(0xFF0A0F0F);
  static const Color cardColor = Color(0xFF1A1F1F);

  late final MapController _mapController;
  double _currentZoom = 12.0;
  bool _isFullScreen = false;
  bool _showSatellite = false;
  bool _isMapReady = false;

  // EV Chargers
  List<Map<String, dynamic>> _evChargers = [];
  final EnvironmentalDataService _envService = EnvironmentalDataService();

  // Selected factor for detailed view
  String _selectedFactor = 'overview';

  // ACO visualization toggle - enabled by default to verify waypoints
  bool _showACONodes = true;

  // API reference data
  final Map<String, String> _apiReferences = {
    'TomTom Traffic': 'Real-time traffic flow data',
    'OpenWeather AQI': 'Air Quality Index from OpenWeather',
    'Open-Meteo Weather': 'Weather conditions and forecast',
    'OpenRouteService': 'Route optimization and elevation',
    'OpenChargeMap': 'EV charging station locations',
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Load EV chargers if electric vehicle
    if (widget.vehicle == 'Electric Car') {
      _loadEVChargers();
    }

    // Center map after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnRoute();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Load EV charging stations near the route
  Future<void> _loadEVChargers() async {
    try {
      // Get points along the route
      final routePoints = widget.routeData.points;

      // Sample points every 2km
      List<LatLng> samplePoints = [];
      double interval = 2000; // meters
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

      // Add start and end points
      samplePoints.add(widget.fromLocation);
      samplePoints.add(widget.toLocation);

      // Find chargers near sample points
      Set<String> chargerIds = {};
      List<Map<String, dynamic>> allChargers = [];

      for (var point in samplePoints) {
        final chargers = await _envService.findEVChargersORS(
          point,
          3000,
        ); // 3km radius
        for (var charger in chargers) {
          if (!chargerIds.contains(charger['id'])) {
            chargerIds.add(charger['id']);

            // Calculate distance from route
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

      setState(() {
        _evChargers = allChargers
          ..sort(
            (a, b) => a['distanceFromRoute'].compareTo(b['distanceFromRoute']),
          );
      });
    } catch (e) {
      debugPrint('Error loading EV chargers: $e');
    }
  }

  /// Center map on the route
  void _centerMapOnRoute() {
    if (!_isMapReady || widget.routeData.points.isEmpty) {
      debugPrint(
        'Warning: Empty route points, route data null, or map not ready',
      );
      _centerOnDefault();
      return;
    }

    try {
      final points = widget.routeData.points;

      // Filter valid points (finite coordinates)
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
        debugPrint('Warning: No valid route points, using default center');
        _centerOnDefault();
        return;
      }

      double minLat = validPoints.map((p) => p.latitude).reduce(math.min);
      double maxLat = validPoints.map((p) => p.latitude).reduce(math.max);
      double minLng = validPoints.map((p) => p.longitude).reduce(math.min);
      double maxLng = validPoints.map((p) => p.longitude).reduce(math.max);

      // Ensure valid bounds - add minimum padding even for very close points
      double latPadding = (maxLat - minLat).abs();
      double lngPadding = (maxLng - minLng).abs();

      // Use minimum padding of 0.001 degrees (~111m) to prevent zoom issues
      const minPadding = 0.001;
      if (latPadding < minPadding) latPadding = minPadding;
      if (lngPadding < minPadding) lngPadding = minPadding;

      // Add 10% additional padding
      latPadding = latPadding * 0.1 + minPadding;
      lngPadding = lngPadding * 0.1 + minPadding;

      // Clamp padding to reasonable values
      latPadding = latPadding.clamp(0.001, 1.0);
      lngPadding = lngPadding.clamp(0.001, 1.0);

      // Validate bounds are within valid ranges
      final southWest = LatLng(
        (minLat - latPadding).clamp(-89.0, 89.0),
        (minLng - lngPadding).clamp(-179.0, 179.0),
      );
      final northEast = LatLng(
        (maxLat + latPadding).clamp(-89.0, 89.0),
        (maxLng + lngPadding).clamp(-179.0, 179.0),
      );

      // Validate bounds are not inverted or zero-size
      if (southWest.latitude >= northEast.latitude ||
          southWest.longitude >= northEast.longitude) {
        debugPrint('Warning: Invalid bounds, using default center');
        _centerOnDefault();
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(southWest, northEast),
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      debugPrint('Error centering map: $e');
      _centerOnDefault();
    }
  }

  /// Center map on default location (between start and end)
  void _centerOnDefault() {
    try {
      final centerLat =
          (widget.fromLocation.latitude + widget.toLocation.latitude) / 2;
      final centerLng =
          (widget.fromLocation.longitude + widget.toLocation.longitude) / 2;

      // Validate center coordinates
      if (!centerLat.isFinite || !centerLng.isFinite) {
        debugPrint('Warning: Invalid center coordinates, using fromLocation');
        _mapController.move(widget.fromLocation, _currentZoom);
        return;
      }

      _mapController.move(
        LatLng(centerLat.clamp(-89.0, 89.0), centerLng.clamp(-179.0, 179.0)),
        _currentZoom,
      );
    } catch (e) {
      debugPrint('Error in _centerOnDefault: $e');
      // Last resort - use from location
      if (widget.fromLocation.latitude.isFinite &&
          widget.fromLocation.longitude.isFinite) {
        _mapController.move(widget.fromLocation, _currentZoom);
      }
    }
  }

  /// Build factor detail card
  Widget _buildFactorDetail(String factor) {
    switch (factor) {
      case 'co2':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CO₂ Emissions & Savings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'CO₂ Emitted',
              '${widget.routeData.co2Emissions.toStringAsFixed(0)}g',
              Icons.co2,
              Colors.brown,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'CO₂ Saved vs Petrol',
              '${widget.routeData.co2Savings.toStringAsFixed(0)}g',
              Icons.eco,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Trees Equivalent',
              '${widget.routeData.treesEquivalent} tree${widget.routeData.treesEquivalent > 1 ? 's' : ''}',
              Icons.park,
              Colors.green,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'One tree absorbs ~22kg CO₂ per year. Your trip saved ${(widget.routeData.co2Savings / 1000).toStringAsFixed(2)}kg!',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'aqi':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Air Quality Index',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildAQIGauge(widget.routeData.averageAQI),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getAQIColor(widget.routeData.averageAQI).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getAQIColor(
                    widget.routeData.averageAQI,
                  ).withAlpha(77),
                ),
              ),
              child: Text(
                widget.routeData.healthRecommendation,
                style: TextStyle(
                  color: _getAQIColor(widget.routeData.averageAQI),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Source: OpenWeather Air Pollution API',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        );

      case 'traffic':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Traffic Conditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildTrafficIndicator(widget.routeData.trafficLevel),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: _getTrafficColor(widget.routeData.trafficLevel),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getTrafficDescription(widget.routeData.trafficLevel),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Source: TomTom Traffic API',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        );

      case 'weather':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather Impact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildWeatherIndicator(widget.routeData.weatherImpact),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getWeatherDescription(widget.routeData.weatherImpact),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Source: Open-Meteo Weather API',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        );

      case 'elevation':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elevation Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Total Elevation Gain',
              '${widget.routeData.totalElevationGain.toStringAsFixed(0)}m',
              Icons.terrain,
              Colors.brown,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Impact on Efficiency',
              _getElevationImpact(widget.routeData.totalElevationGain),
              Icons.speed,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            const Text(
              'Data Source: Open-Elevation API / OpenRouteService',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        );

      default:
        return _buildOverviewDetails();
    }
  }

  Widget _buildOverviewDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Journey Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Stats grid
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStatTile(
              'Distance',
              '${widget.routeData.distance.toStringAsFixed(1)} km',
              Icons.straighten,
              Colors.blue,
            ),
            _buildStatTile(
              'Duration',
              _formatDuration(widget.routeData.duration * 60),
              Icons.timer,
              Colors.orange,
            ),
            _buildStatTile(
              'CO₂',
              '${widget.routeData.co2Emissions.toStringAsFixed(0)}g',
              Icons.co2,
              Colors.brown,
            ),
            _buildStatTile(
              'Eco Score',
              '${widget.ecoPoints}',
              Icons.eco,
              Colors.green,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Environmental impact card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade900, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  Icon(Icons.eco, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Text(
                    'Environmental Impact',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildImpactItem(
                    '${widget.routeData.co2Savings.toStringAsFixed(0)}g',
                    'CO₂ Saved',
                    Icons.cloud_queue,
                  ),
                  _buildImpactItem(
                    '${widget.routeData.treesEquivalent}',
                    'Trees Equivalent',
                    Icons.park,
                  ),
                  _buildImpactItem(
                    '${(widget.routeData.averageAQI).round()}',
                    'Avg AQI',
                    Icons.air,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // API References
        const Text(
          'Data Sources',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._apiReferences.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 12),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildImpactItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAQIGauge(double aqi) {
    double percentage = (aqi / 300).clamp(0.0, 1.0);
    Color color = _getAQIColor(aqi);

    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeWidth: 10,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  aqi.round().toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getAQILabel(aqi),
                  style: TextStyle(color: color, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficIndicator(double traffic) {
    Color color = _getTrafficColor(traffic);
    String level = traffic < 0.3
        ? 'Light'
        : (traffic < 0.6 ? 'Moderate' : 'Heavy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Traffic Level: $level',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: traffic,
          backgroundColor: Colors.grey[800],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildWeatherIndicator(double weather) {
    String description = _getWeatherDescription(weather);
    Color color = weather < 0.3
        ? Colors.green
        : (weather < 0.6 ? Colors.orange : Colors.red);

    return Row(
      children: [
        Icon(
          weather < 0.3
              ? Icons.wb_sunny
              : (weather < 0.6 ? Icons.wb_cloudy : Icons.thunderstorm),
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  String _getAQILabel(double aqi) {
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive';
    if (aqi <= 200) return 'Unhealthy';
    return 'Very Unhealthy';
  }

  String _getTrafficDescription(double traffic) {
    if (traffic < 0.3) {
      return 'Light traffic - smooth journey expected';
    } else if (traffic < 0.6) {
      return 'Moderate traffic - some delays possible';
    } else {
      return 'Heavy traffic - significant delays expected';
    }
  }

  String _getWeatherDescription(double weather) {
    if (weather < 0.2) {
      return 'Clear conditions - no weather impact';
    } else if (weather < 0.4) {
      return 'Light rain/clouds - minor impact';
    } else if (weather < 0.6) {
      return 'Moderate weather - reduced visibility/speed';
    } else {
      return 'Severe weather - significant caution needed';
    }
  }

  String _getElevationImpact(double elevation) {
    if (elevation < 50) return 'Minimal impact';
    if (elevation < 150) return 'Moderate impact';
    if (elevation < 300) return 'Significant impact';
    return 'High impact - reduced efficiency';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: _isFullScreen ? _buildFullScreenLayout() : _buildNormalLayout(),
    );
  }

  Widget _buildNormalLayout() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(flex: 5, child: _buildMap()),
          Expanded(flex: 5, child: _buildDetailsPanel()),
        ],
      ),
    );
  }

  Widget _buildFullScreenLayout() {
    return Stack(
      children: [
        _buildMap(),
        Positioned(
          top: 40,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(30),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => setState(() => _isFullScreen = false),
            ),
          ),
        ),
        Positioned(top: 40, right: 16, child: _buildMapControls()),
      ],
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Eco Route',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.from} → ${widget.to}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(_getVehicleIcon(), color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.vehicle,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(
              (widget.fromLocation.latitude + widget.toLocation.latitude) / 2,
              (widget.fromLocation.longitude + widget.toLocation.longitude) / 2,
            ),
            initialZoom: _currentZoom,
            onMapReady: () {
              setState(() => _isMapReady = true);
              _centerMapOnRoute();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _showSatellite
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sustainable_travel_app',
            ),

            // Route polyline - use route color based on route type
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.routeData.points,
                  color: widget.routeColor,
                  strokeWidth: 6,
                ),
              ],
            ),

            // EV Charger markers
            if (_evChargers.isNotEmpty && widget.vehicle == 'Electric Car')
              MarkerLayer(
                markers: _evChargers
                    .map(
                      (charger) => Marker(
                        point: charger['location'],
                        width: 30,
                        height: 30,
                        child: GestureDetector(
                          onTap: () => _showChargerDetails(charger),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(77),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.ev_station,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

            // ACO nodes - black dots for each waypoint (when toggle is enabled)
            // Made larger and more visible for debugging
            if (_showACONodes)
              MarkerLayer(
                markers: widget.routeData.points
                    .map(
                      (point) => Marker(
                        point: point,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.yellow, width: 2),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

            // Start and end markers
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.fromLocation,
                  width: 40,
                  height: 50,
                  child: _buildMarker(brandGreen, Icons.location_on, 'Start'),
                ),
                Marker(
                  point: widget.toLocation,
                  width: 40,
                  height: 50,
                  child: _buildMarker(Colors.red, Icons.flag, 'End'),
                ),
              ],
            ),
          ],
        ),

        // Map controls
        if (!_isFullScreen) _buildMapControls(),

        // Route stats overlay
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: brandGreen.withAlpha(77), width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.straighten, color: brandGreen, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatDistance(widget.routeData.distance * 1000),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(widget.routeData.duration * 60),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        children: [
          _buildMapControlButton(
            icon: Icons.add,
            onPressed: () {
              setState(() {
                _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0);
                _mapController.move(_mapController.camera.center, _currentZoom);
              });
            },
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.remove,
            onPressed: () {
              setState(() {
                _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0);
                _mapController.move(_mapController.camera.center, _currentZoom);
              });
            },
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: _showSatellite ? Icons.map : Icons.satellite,
            onPressed: () => setState(() => _showSatellite = !_showSatellite),
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.fullscreen,
            onPressed: () => setState(() => _isFullScreen = true),
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: Icons.center_focus_strong,
            onPressed: _centerMapOnRoute,
          ),
          const SizedBox(height: 8),
          _buildMapControlButton(
            icon: _showACONodes ? Icons.hub : Icons.blur_on,
            onPressed: () => setState(() => _showACONodes = !_showACONodes),
            isActive: _showACONodes,
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Color color, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 7),
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isActive ? brandGreen : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 8),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: isActive ? Colors.white : brandGreen, size: 22),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Factor selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFactorChip('Overview', 'overview', Icons.dashboard),
                const SizedBox(width: 8),
                _buildFactorChip('CO₂', 'co2', Icons.co2),
                const SizedBox(width: 8),
                _buildFactorChip('Air Quality', 'aqi', Icons.air),
                const SizedBox(width: 8),
                _buildFactorChip('Traffic', 'traffic', Icons.traffic),
                const SizedBox(width: 8),
                _buildFactorChip('Weather', 'weather', Icons.wb_sunny),
                const SizedBox(width: 8),
                _buildFactorChip('Elevation', 'elevation', Icons.terrain),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Factor details - use Flexible instead of Expanded for better handling
          Flexible(
            child: SingleChildScrollView(
              child: _buildFactorDetail(_selectedFactor),
            ),
          ),

          const SizedBox(height: 12),

          // Start journey button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startJourney,
              icon: const Icon(Icons.navigation),
              label: const Text(
                'Start Journey',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorChip(String label, String value, IconData icon) {
    bool isSelected = _selectedFactor == value;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFactor = value;
        });
      },
      backgroundColor: Colors.grey[900],
      selectedColor: brandGreen,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
        fontSize: 12,
      ),
    );
  }

  void _showChargerDetails(Map<String, dynamic> charger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          charger['name'],
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Operator',
              charger['operator'],
              Icons.business,
              Colors.grey,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Distance from route',
              '${(charger['distanceFromRoute'] / 1000).toStringAsFixed(1)} km',
              Icons.straighten,
              Colors.blue,
            ),
            if (charger['capacity'] != 'Unknown') ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Capacity',
                charger['capacity'],
                Icons.power,
                Colors.orange,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: brandGreen),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startJourney() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyTrackingScreen(
          from: widget.from,
          to: widget.to,
          vehicle: widget.vehicle,
          fromLocation: widget.fromLocation,
          toLocation: widget.toLocation,
          routePoints: widget.routeData.points,
          totalDistance:
              widget.routeData.distance * 1000, // Convert km to meters
          totalDuration:
              widget.routeData.duration * 60, // Convert minutes to seconds
          ecoPoints: widget.ecoPoints,
        ),
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

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '0 min';
    int hours = (seconds / 3600).floor();
    int minutes = ((seconds % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}min';
  }
}
