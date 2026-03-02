import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'select_location_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'my_trips_page.dart';
import 'logout_page.dart';
import 'leaderboard_page.dart';
import '../providers/auth_provider.dart';
import '../services/eco_points_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _airQualityData;
  bool _isLoading = true;
  bool _isAirQualityLoading = false;
  Position? _currentPosition;
  bool _isUsingFallbackLocation = false;
  bool _isLocationLoading = false;

  // User stats
  int _totalTrips = 0;
  double _ecoPoints = 0.0;
  double _co2Saved = 0.0;
  int? _rank;

  final EcoPointsService _ecoPointsService = EcoPointsService();

  // Your OpenWeatherMap API Key
  static const String _apiKey = 'YOUR_OPENWEATHER_API_KEY';

  // Palakkad coordinates
  static const double _palakkadLat = 10.7867;
  static const double _palakkadLon = 76.6548;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
    _fetchUserStats();
  }

  Future<void> _refreshAllData() async {
    // Refresh weather and air quality data
    await _fetchWeatherData();
    // Refresh user stats
    await _fetchUserStats();
  }

  Future<void> _refreshLocation() async {
    if (_isLocationLoading) return;

    setState(() {
      _isLocationLoading = true;
    });

    try {
      await _fetchWeatherFromDeviceLocation();
    } catch (e) {
      if (kDebugMode) {
        print('Location refresh error: $e');
      }
      setState(() {
        _isUsingFallbackLocation = true;
      });
      await _fetchWeatherByCoordinates(
        _palakkadLat,
        _palakkadLon,
        isFallback: true,
      );
      await _fetchAirQualityData(_palakkadLat, _palakkadLon, isFallback: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserStats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null && !user.isGuest) {
      try {
        final userId = int.parse(user.uid);
        final dashboard = await _ecoPointsService.getDashboard(userId);

        if (dashboard != null && mounted) {
          setState(() {
            _totalTrips = dashboard['total_trips'] ?? 0;
            _ecoPoints = (dashboard['total_eco_points'] ?? 0).toDouble();
            _co2Saved = (dashboard['total_co2_saved'] ?? 0).toDouble();
            _rank = dashboard['rank'];
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user stats: $e');
        }
      }
    }
  }

  Future<void> _fetchWeatherData() async {
    try {
      await _fetchWeatherFromDeviceLocation();
    } catch (e) {
      if (kDebugMode) {
        print('Location error: $e');
      }
      setState(() {
        _isUsingFallbackLocation = true;
      });
      await _fetchWeatherByCoordinates(
        _palakkadLat,
        _palakkadLon,
        isFallback: true,
      );
      await _fetchAirQualityData(_palakkadLat, _palakkadLon, isFallback: true);
    }
  }

  Future<void> _fetchWeatherFromDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location service disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position with timeout to prevent indefinite spinning
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Location request timed out');
            },
          );

      setState(() {
        _currentPosition = position;
        _isUsingFallbackLocation = false;
      });

      await _fetchWeatherByCoordinates(position.latitude, position.longitude);
      await _fetchAirQualityData(position.latitude, position.longitude);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchWeatherByCoordinates(
    double lat,
    double lon, {
    bool isFallback = false,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (isFallback || _isUsingFallbackLocation) {
          data['name'] = 'Palakkad, IN';
          data['sys']['country'] = 'IN';
        }

        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _loadMockWeatherData();
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadMockWeatherData();
      });
    }
  }

  Future<void> _fetchAirQualityData(
    double lat,
    double lon, {
    bool isFallback = false,
  }) async {
    setState(() {
      _isAirQualityLoading = true;
    });

    try {
      final url = Uri.parse(
        'http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (isFallback || _isUsingFallbackLocation) {
          data['coord'] = {'lon': _palakkadLon, 'lat': _palakkadLat};
        }

        setState(() {
          _airQualityData = data;
          _isAirQualityLoading = false;
        });
      } else {
        _loadMockAirQualityData();
      }
    } catch (e) {
      _loadMockAirQualityData();
    }
  }

  void _loadMockWeatherData() {
    final mockData = {
      'name': 'Palakkad, IN',
      'main': {
        'temp': 31.5,
        'feels_like': 34.2,
        'humidity': 70,
        'pressure': 1011,
      },
      'weather': [
        {'id': 800, 'main': 'Clear', 'description': 'clear sky', 'icon': '01d'},
      ],
      'wind': {'speed': 3.2},
      'sys': {
        'country': 'IN',
        'sunrise': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 21600,
        'sunset': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 64800,
      },
    };

    Future.delayed(Duration.zero, () {
      setState(() {
        _weatherData = mockData;
      });
    });
  }

  void _loadMockAirQualityData() {
    final mockData = {
      'coord': {'lon': _palakkadLon, 'lat': _palakkadLat},
      'list': [
        {
          'main': {'aqi': 2},
          'components': {
            'co': 210.3,
            'no': 0.15,
            'no2': 1.4,
            'o3': 52.4,
            'so2': 0.4,
            'pm2_5': 10.5,
            'pm10': 20.1,
            'nh3': 0.5,
          },
          'dt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      ],
    };

    Future.delayed(Duration.zero, () {
      setState(() {
        _airQualityData = mockData;
        _isAirQualityLoading = false;
      });
    });
  }

  String _getDisplayCityName() {
    if (_weatherData == null) return 'Current Location';

    final apiCityName = _weatherData!['name'] ?? 'Current Location';

    if (_isUsingFallbackLocation ||
        apiCityName.contains('Kochi') ||
        apiCityName.contains('Ernakulam') ||
        apiCityName.contains('Cochin')) {
      return 'Palakkad';
    }

    return apiCityName.split(',')[0];
  }

  String _getShortLocationName() {
    final cityName = _getDisplayCityName();
    if (cityName.length > 12) {
      return '${cityName.substring(0, 10)}...';
    }
    return cityName;
  }

  String _getAQILevel(int aqi) {
    switch (aqi) {
      case 1:
        return 'Good';
      case 2:
        return 'Fair';
      case 3:
        return 'Moderate';
      case 4:
        return 'Poor';
      case 5:
        return 'Very Poor';
      default:
        return 'Unknown';
    }
  }

  Color _getAQIColor(int aqi) {
    switch (aqi) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getAQIIcon(int aqi) {
    switch (aqi) {
      case 1:
        return '😊';
      case 2:
        return '🙂';
      case 3:
        return '😐';
      case 4:
        return '😷';
      case 5:
        return '😨';
      default:
        return '🌫️';
    }
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp < 25) return Colors.lightBlue;
    if (temp < 30) return Colors.green;
    if (temp < 35) return Colors.orange;
    return Colors.red;
  }

  String _getWeatherIcon(int? weatherId) {
    if (weatherId == null) return '☀️';
    if (weatherId == 800) return '☀️';
    if (weatherId == 801) return '🌤️';
    if (weatherId == 802) return '⛅';
    if (weatherId == 803 || weatherId == 804) return '☁️';
    if (weatherId >= 500 && weatherId < 600) return '🌧️';
    if (weatherId >= 300 && weatherId < 400) return '🌦️';
    if (weatherId >= 200 && weatherId < 300) return '⛈️';
    if (weatherId >= 600 && weatherId < 700) return '❄️';
    if (weatherId >= 700 && weatherId < 800) return '🌫️';
    return '☀️';
  }

  Color _colorWithOpacity(Color color, double opacity) {
    // ignore: deprecated_member_use
    return color.withOpacity(opacity);
  }

  Widget _buildWeatherWidget() {
    if (_isLoading) {
      return _buildFeatureCard(
        icon: Icons.cloud,
        title: "Weather",
        color: Colors.lightBlue,
        subtitle: "Loading...",
      );
    }

    if (_weatherData == null) {
      return _buildFeatureCard(
        icon: Icons.cloud_off,
        title: "Weather",
        color: Colors.lightBlue,
        subtitle: "No Data",
      );
    }

    final temp = _weatherData!['main']['temp']?.toDouble() ?? 0.0;
    final feelsLike = _weatherData!['main']['feels_like']?.toDouble() ?? temp;
    final description = _weatherData!['weather'][0]['description'] ?? '--';
    final tempColor = _getTemperatureColor(temp);
    final weatherIcon = _getWeatherIcon(_weatherData!['weather'][0]['id']);

    return GestureDetector(
      onTap: () => _showWeatherDetails(context),
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _colorWithOpacity(tempColor, 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _colorWithOpacity(tempColor, 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(weatherIcon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${temp.round()}°C",
                      style: TextStyle(
                        color: tempColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Feels ${feelsLike.round()}°C",
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description.toString().toUpperCase(),
              style: TextStyle(
                color: tempColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirQualityWidget() {
    if (_isAirQualityLoading && _airQualityData == null) {
      return _buildFeatureCard(
        icon: Icons.air,
        title: "Air Quality",
        color: Colors.blue,
        subtitle: "Loading...",
      );
    }

    if (_airQualityData == null) {
      return _buildFeatureCard(
        icon: Icons.air,
        title: "Air Quality",
        color: Colors.blue,
        subtitle: "No Data",
      );
    }

    final aqiData = _airQualityData!['list']?[0];
    final aqi = aqiData?['main']?['aqi'] ?? 0;
    final aqiLevel = _getAQILevel(aqi);
    final aqiColor = _getAQIColor(aqi);
    final aqiIcon = _getAQIIcon(aqi);

    return GestureDetector(
      onTap: () => _showAirQualityDetails(context),
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _colorWithOpacity(aqiColor, 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _colorWithOpacity(aqiColor, 0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(aqiIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              "AQI $aqi",
              style: TextStyle(
                color: aqiColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              aqiLevel,
              style: TextStyle(
                color: _colorWithOpacity(aqiColor, 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showWeatherDetails(BuildContext context) {
    if (_weatherData == null) return;

    final main = _weatherData!['main'];
    final weather = _weatherData!['weather'][0];
    final wind = _weatherData!['wind'];
    final sys = _weatherData!['sys'];

    final temp = main['temp']?.round() ?? '--';
    final feelsLike = main['feels_like']?.round() ?? '--';
    final humidity = main['humidity'] ?? '--';
    final pressure = main['pressure'] ?? '--';
    final description = weather['description'] ?? '--';
    final windSpeed = wind['speed']?.round() ?? '--';
    final sunrise = DateTime.fromMillisecondsSinceEpoch(sys['sunrise'] * 1000);
    final sunset = DateTime.fromMillisecondsSinceEpoch(sys['sunset'] * 1000);
    final displayCity = _getDisplayCityName();
    final country = sys['country'] ?? '';
    final tempColor = _getTemperatureColor(main['temp']?.toDouble() ?? 0.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151717),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
        title: Row(
          children: [
            Text(
              _getWeatherIcon(weather['id']),
              style: const TextStyle(fontSize: 30),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayCity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    country.isNotEmpty ? country : '',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  Text(
                    description.toString().toUpperCase(),
                    style: TextStyle(
                      color: tempColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  '$temp°C',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: tempColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Feels like $feelsLike°C',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildWeatherDetailRow(
                'Humidity',
                '$humidity%',
                Icons.water_drop,
              ),
              _buildWeatherDetailRow(
                'Pressure',
                '$pressure hPa',
                Icons.compress,
              ),
              _buildWeatherDetailRow('Wind Speed', '$windSpeed m/s', Icons.air),
              _buildWeatherDetailRow(
                'Sunrise',
                DateFormat('HH:mm').format(sunrise),
                Icons.wb_sunny,
              ),
              _buildWeatherDetailRow(
                'Sunset',
                DateFormat('HH:mm').format(sunset),
                Icons.nightlight_round,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF43A047)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAirQualityDetails(BuildContext context) {
    if (_airQualityData == null) return;

    final aqiData = _airQualityData!['list']?[0];
    final aqi = aqiData?['main']?['aqi'] ?? 0;
    final components = aqiData?['components'] ?? {};
    final aqiLevel = _getAQILevel(aqi);
    final aqiColor = _getAQIColor(aqi);
    final aqiIcon = _getAQIIcon(aqi);
    final displayCity = _getDisplayCityName();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151717),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
        title: Row(
          children: [
            Text(aqiIcon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Air Quality',
                    style: TextStyle(
                      color: aqiColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    displayCity,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    aqiLevel.toUpperCase(),
                    style: TextStyle(
                      color: aqiColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'AQI $aqi',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: aqiColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  aqiLevel,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildWeatherDetailRow(
                'CO',
                '${components['co'] ?? '--'} μg/m³',
                Icons.co2,
              ),
              _buildWeatherDetailRow(
                'O₃',
                '${components['o3'] ?? '--'} μg/m³',
                Icons.waves,
              ),
              _buildWeatherDetailRow(
                'NO₂',
                '${components['no2'] ?? '--'} μg/m³',
                Icons.air,
              ),
              _buildWeatherDetailRow(
                'SO₂',
                '${components['so2'] ?? '--'} μg/m³',
                Icons.whatshot,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF43A047)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade400)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      height: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _colorWithOpacity(color, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colorWithOpacity(color, 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color darkGreen = Color(0xFF0A3D0A);
    const Color backgroundColor = Color(0xFF151717);

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final displayEcoPoints = user?.ecoPoints ?? _ecoPoints;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [darkGreen, backgroundColor],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  centerTitle: false,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Way2Sustain",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            "EcoPoints: ",
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          Text(
                            displayEcoPoints.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    GestureDetector(
                      onTap: _isLocationLoading ? null : _refreshLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _colorWithOpacity(Colors.grey.shade900, 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _colorWithOpacity(Colors.grey.shade700, 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isLocationLoading
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: brandGreen,
                                    ),
                                  )
                                : Icon(
                                    Icons.location_on,
                                    color: brandGreen,
                                    size: 14,
                                  ),
                            const SizedBox(width: 6),
                            Text(
                              _getShortLocationName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_weatherData != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                _getWeatherIcon(
                                  _weatherData!['weather'][0]['id'],
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_weatherData!['main']['temp']?.round() ?? '--'}°C',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: PopupMenuButton<String>(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == "profile") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                          } else if (value == "settings") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          } else if (value == "trips") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyTripsPage(),
                              ),
                            );
                          } else if (value == "logout") {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LogoutPage(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: "profile",
                            child: ListTile(
                              leading: Icon(Icons.person),
                              title: Text("Profile"),
                            ),
                          ),
                          const PopupMenuItem(
                            value: "settings",
                            child: ListTile(
                              leading: Icon(Icons.settings),
                              title: Text("Settings"),
                            ),
                          ),
                          const PopupMenuItem(
                            value: "trips",
                            child: ListTile(
                              leading: Icon(Icons.map),
                              title: Text("My Trips"),
                            ),
                          ),
                          const PopupMenuItem(
                            value: "logout",
                            child: ListTile(
                              leading: Icon(Icons.logout, color: Colors.red),
                              title: Text(
                                "Logout",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                        child: const CircleAvatar(
                          radius: 20,
                          backgroundColor: brandGreen,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAllData,
                    color: brandGreen,
                    backgroundColor: const Color(0xFF151717),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        children: [
                          Container(
                            height: 150,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(20),
                              ),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(
                                    _currentPosition?.latitude ?? _palakkadLat,
                                    _currentPosition?.longitude ?? _palakkadLon,
                                  ),
                                  initialZoom: 13.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.sustainable_travel_app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(
                                          _currentPosition?.latitude ??
                                              _palakkadLat,
                                          _currentPosition?.longitude ??
                                              _palakkadLon,
                                        ),
                                        width: 50.0,
                                        height: 50.0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _colorWithOpacity(
                                              brandGreen,
                                              0.3,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: brandGreen,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: brandGreen,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(16.0),
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              color: _colorWithOpacity(Colors.black, 0.5),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(20),
                              ),
                              border: Border.all(
                                color: _colorWithOpacity(Colors.white, 0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.eco,
                                  size: 60,
                                  color: brandGreen,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "Welcome to Way2Sustain!",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Plan your sustainable travel journey",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const SelectLocationPage(),
                                      ),
                                    ),
                                    icon: const Icon(Icons.route),
                                    label: const Text("Plan New Journey"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brandGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 0.85,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const LeaderboardPage(),
                                          ),
                                        );
                                      },
                                      child: _buildFeatureCard(
                                        icon: Icons.leaderboard,
                                        title: "Leaderboard",
                                        color: Colors.amber,
                                        subtitle: "Rank #${_rank ?? '--'}",
                                      ),
                                    ),
                                    _buildAirQualityWidget(),
                                    _buildFeatureCard(
                                      icon: Icons.co2,
                                      title: "Carbon Track",
                                      color: brandGreen,
                                      subtitle:
                                          "${_co2Saved.toStringAsFixed(1)} kg",
                                    ),
                                    _buildWeatherWidget(),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _colorWithOpacity(
                                      Colors.grey.shade900,
                                      0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        icon: Icons.directions_car,
                                        value: _totalTrips.toString(),
                                        label: "Trips",
                                      ),
                                      _buildStatItem(
                                        icon: Icons.forest,
                                        value:
                                            "${_co2Saved.toStringAsFixed(1)} kg",
                                        label: "CO₂ Saved",
                                      ),
                                      _buildStatItem(
                                        icon: Icons.local_fire_department,
                                        value: displayEcoPoints.toStringAsFixed(
                                          0,
                                        ),
                                        label: "Points",
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
