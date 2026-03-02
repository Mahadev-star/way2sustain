import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../home/home_page.dart';
import '../services/eco_points_service.dart';

class JourneyTrackingScreen extends StatefulWidget {
  final String from;
  final String to;
  final String vehicle;
  final int ecoPoints;
  final LatLng fromLocation;
  final LatLng toLocation;
  final List<LatLng> routePoints;
  final double totalDistance; // in meters
  final double totalDuration; // in seconds

  const JourneyTrackingScreen({
    super.key,
    required this.from,
    required this.to,
    required this.vehicle,
    required this.ecoPoints,
    required this.fromLocation,
    required this.toLocation,
    required this.routePoints,
    required this.totalDistance,
    required this.totalDuration,
  });

  @override
  State<JourneyTrackingScreen> createState() => _JourneyTrackingScreenState();
}

class _JourneyTrackingScreenState extends State<JourneyTrackingScreen>
    with TickerProviderStateMixin {
  static const Color brandGreen = Color(0xFF43A047);
  static const Color backgroundColor = Color(0xFF0A0F0F);
  static const Color cardColor = Color(0xFF1A1F1F);
  // ignore: constant_identifier_names
  static const double ALERT_DISTANCE = 100.0; // 100 meters alert

  // Services for backend integration
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final EcoPointsService _ecoPointsService = EcoPointsService();

  late final MapController _mapController;
  double _currentZoom = 16.0;
  LatLng? _currentLocation;
  double _distanceCovered = 0.0;
  double _timeElapsed = 0.0;
  double _progress = 0.0;
  bool _isJourneyActive = true;
  bool _isPaused = false;
  Timer? _movementTimer;
  int _currentPointIndex = 0;
  double _currentSpeed = 0.0;
  String _nextInstruction = '';
  double _distanceToNextTurn = 0.0;
  String _alertMessage = '';
  bool _showAlert = false;
  Timer? _alertTimer;

  /// Get instruction without distance for cleaner display
  String get _nextInstructionWithoutDistance {
    if (_nextInstruction.contains('Turn left')) {
      return 'Turn left';
    } else if (_nextInstruction.contains('Turn right')) {
      return 'Turn right';
    } else if (_nextInstruction.contains('straight')) {
      return 'Continue straight';
    }
    return _nextInstruction;
  }

  // For celebration
  bool _showCelebration = false;
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;
  final List<ConfettiParticle> _confettiParticles = [];

  // Speed tracking
  double _baseSpeed = 0.0;
  final List<double> _recentSpeeds = [];
  static const int _speedSamplesForAverage = 5;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLocation = widget.fromLocation;
    _calculateBaseSpeed();
    _setupConfetti();
    _startRealisticMovement();
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _alertTimer?.cancel();
    _confettiController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _setupConfetti() {
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _confettiAnimation = CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    );

    // Generate confetti particles
    for (int i = 0; i < 50; i++) {
      _confettiParticles.add(
        ConfettiParticle(
          offset: Offset(
            math.Random().nextDouble() * 400,
            math.Random().nextDouble() * 800,
          ),
          velocity: Offset(
            (math.Random().nextDouble() - 0.5) * 2,
            math.Random().nextDouble() * 3 + 2,
          ),
          color:
              Colors.primaries[math.Random().nextInt(Colors.primaries.length)],
          size: math.Random().nextDouble() * 10 + 5,
        ),
      );
    }
  }

  void _calculateBaseSpeed() {
    // Base speeds in m/s
    switch (widget.vehicle) {
      case 'Walking':
        _baseSpeed = 1.4; // 5 km/h
        break;
      case 'Bicycle':
        _baseSpeed = 4.2; // 15 km/h
        break;
      case 'Electric Car':
      case 'Petrol Car':
        _baseSpeed = 11.1; // 40 km/h (urban average)
        break;
      default:
        _baseSpeed = 8.3; // 30 km/h
    }
    _currentSpeed = _baseSpeed;
  }

  void _startRealisticMovement() {
    if (widget.routePoints.length < 2) return;

    const updateInterval = Duration(milliseconds: 500); // Update every 500ms
    int targetPointIndex = 1;

    _movementTimer = Timer.periodic(updateInterval, (timer) {
      if (!_isJourneyActive ||
          _isPaused ||
          _currentPointIndex >= widget.routePoints.length - 1) {
        if (_currentPointIndex >= widget.routePoints.length - 1 &&
            !_showCelebration) {
          _isJourneyActive = false;
          timer.cancel();
          _showJourneyComplete();
        }
        return;
      }

      // Add speed variation for realism (±20% every update)
      final variation = 0.8 + (math.Random().nextDouble() * 0.4); // 0.8 to 1.2
      double instantSpeed = _baseSpeed * variation;

      // Add to recent speeds list for smoothing
      _recentSpeeds.add(instantSpeed);
      if (_recentSpeeds.length > _speedSamplesForAverage) {
        _recentSpeeds.removeAt(0);
      }

      // Calculate average speed for smooth changes
      if (_recentSpeeds.isNotEmpty) {
        _currentSpeed =
            _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
      }

      // Calculate movement based on current speed
      LatLng currentTarget = widget.routePoints[targetPointIndex];
      LatLng currentPos = _currentLocation!;

      // Calculate distance to next point
      double distanceToTarget = const Distance().distance(
        currentPos,
        currentTarget,
      );

      // Calculate how much to move in this update (speed * time interval)
      double moveDistance =
          _currentSpeed * (updateInterval.inMilliseconds / 1000);

      if (distanceToTarget <= moveDistance) {
        // Reached the next point
        setState(() {
          _currentLocation = currentTarget;
          _currentPointIndex = targetPointIndex;
          _progress = _currentPointIndex / (widget.routePoints.length - 1);
          _distanceCovered = widget.totalDistance * _progress;
          _timeElapsed = widget.totalDuration * _progress;

          // Move to next segment
          if (targetPointIndex < widget.routePoints.length - 1) {
            targetPointIndex++;

            // Check for upcoming turns
            _checkUpcomingTurn();
          }

          // Smooth map following
          _mapController.move(_currentLocation!, _currentZoom);
        });
      } else {
        // Move partway to next point
        double ratio = moveDistance / distanceToTarget;
        double newLat =
            currentPos.latitude +
            (currentTarget.latitude - currentPos.latitude) * ratio;
        double newLng =
            currentPos.longitude +
            (currentTarget.longitude - currentPos.longitude) * ratio;

        setState(() {
          _currentLocation = LatLng(newLat, newLng);
          _distanceCovered += moveDistance;
          _timeElapsed =
              (_distanceCovered / widget.totalDistance) * widget.totalDuration;
          _progress = _distanceCovered / widget.totalDistance;

          // Update distance to next turn
          _distanceToNextTurn = distanceToTarget - moveDistance;

          // Smooth map following
          _mapController.move(_currentLocation!, _currentZoom);
        });
      }
    });
  }

  void _checkUpcomingTurn() {
    if (_currentPointIndex >= widget.routePoints.length - 2) return;

    LatLng currentPos = widget.routePoints[_currentPointIndex];
    LatLng nextPos = widget.routePoints[_currentPointIndex + 1];
    LatLng nextNextPos = widget.routePoints[_currentPointIndex + 2];

    // Calculate bearing to next point and point after
    double bearing1 = _calculateBearing(currentPos, nextPos);
    double bearing2 = _calculateBearing(nextPos, nextNextPos);

    // Calculate turn angle
    double turnAngle = (bearing2 - bearing1).abs();
    if (turnAngle > 180) turnAngle = 360 - turnAngle;

    // Determine turn direction
    String turnDirection;
    if (turnAngle < 30) {
      turnDirection = 'straight';
    } else if (bearing2 > bearing1) {
      turnDirection = 'right';
    } else {
      turnDirection = 'left';
    }

    // Calculate distance to turn
    _distanceToNextTurn = const Distance().distance(currentPos, nextPos);

    // Set instruction
    if (turnDirection == 'straight') {
      _nextInstruction = 'Continue straight';
    } else {
      _nextInstruction =
          'Turn $turnDirection in ${_formatDistance(_distanceToNextTurn)}';
    }

    // Show alert if within alert distance
    if (_distanceToNextTurn <= ALERT_DISTANCE && turnDirection != 'straight') {
      _showTurnAlert(turnDirection);
    }
  }

  double _calculateBearing(LatLng from, LatLng to) {
    double lat1 = from.latitude * math.pi / 180;
    double lat2 = to.latitude * math.pi / 180;
    double lon1 = from.longitude * math.pi / 180;
    double lon2 = to.longitude * math.pi / 180;

    double y = math.sin(lon2 - lon1) * math.cos(lat2);
    double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(lon2 - lon1);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _showTurnAlert(String direction) {
    setState(() {
      _alertMessage = '⚠️ Turn $direction in 100m';
      _showAlert = true;
    });

    // Vibrate for alert
    HapticFeedback.heavyImpact();

    // Auto-hide alert after 3 seconds
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showAlert = false;
        });
      }
    });
  }

  Future<void> _saveTripToBackend() async {
    try {
      final userIdStr = await _secureStorage.read(key: 'current_user_id');
      if (userIdStr != null) {
        final userId = int.parse(userIdStr);
        final distanceKm = widget.totalDistance / 1000;
        final durationMin = widget.totalDuration / 60;
        final routeType = widget.ecoPoints > 50
            ? 'eco'
            : (widget.ecoPoints > 25 ? 'balanced' : 'normal');

        await _ecoPointsService.addTrip(
          userId: userId,
          distance: distanceKm,
          duration: durationMin,
          routeType: routeType,
          startLocation: widget.from,
          endLocation: widget.to,
        );
      }
    } catch (e) {
      debugPrint('Error saving trip: $e');
    }
  }

  void _showJourneyComplete() {
    setState(() {
      _showCelebration = true;
    });

    // Save trip to backend
    _saveTripToBackend();

    // Start confetti animation
    _confettiController.forward();

    // Show celebration dialog after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showCelebrationDialog();
      }
    });
  }

  void _showCelebrationDialog() {
    int earnedPoints = (_progress * widget.ecoPoints).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎉 Journey Complete! 🎉',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: brandGreen.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Color(0xFF43A047),
                size: 80,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You have earned',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '$earnedPoints ECO POINTS',
              style: const TextStyle(
                color: Color(0xFF43A047),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildAchievementRow(
                    Icons.eco,
                    'Carbon Savings',
                    '${_calculateCO2Saved().toStringAsFixed(0)}g CO₂',
                  ),
                  const Divider(color: Colors.grey),
                  _buildAchievementRow(
                    Icons.straighten,
                    'Distance Traveled',
                    _formatDistance(_distanceCovered),
                  ),
                  const Divider(color: Colors.grey),
                  _buildAchievementRow(
                    Icons.timer,
                    'Time Taken',
                    _formatDuration(_timeElapsed),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _confettiController.stop();
                    Navigator.pop(context);
                    _showThankYouAndNavigateHome();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    _confettiController.stop();
                    Navigator.pop(context);
                    _showShareOptions();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: brandGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: brandGreen, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
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

  double _calculateCO2Saved() {
    if (widget.vehicle == 'Walking' || widget.vehicle == 'Bicycle') {
      return (widget.totalDistance / 1000) * 120;
    }
    double baseCO2 = widget.vehicle == 'Electric Car' ? 50.0 : 120.0;
    return (widget.totalDistance / 1000) * (120 - baseCO2);
  }

  void _showThankYouAndNavigateHome() {
    // Show thank you message
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: brandGreen.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: Color(0xFF43A047),
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank you for using our app',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Way2Sustain 💚',
              style: TextStyle(
                color: Color(0xFF43A047),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to Home Page
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions() {
    int earnedPoints = (_progress * widget.ecoPoints).round();
    double co2Saved = _calculateCO2Saved() / 1000; // Convert to kg
    String shareMessage =
        'I just completed an eco-friendly trip using Way2Sustain 🌱\n'
        'I saved ${co2Saved.toStringAsFixed(2)} kg CO₂ and earned $earnedPoints eco points!\n'
        'Join me in sustainable travel!';

    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Share Your Achievement',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () => _shareToWhatsApp(shareMessage),
                ),
                _buildShareButton(
                  icon: Icons.send,
                  label: 'Telegram',
                  color: Colors.blue,
                  onTap: () => _shareToTelegram(shareMessage),
                ),
                _buildShareButton(
                  icon: Icons.email,
                  label: 'Gmail',
                  color: Colors.red,
                  onTap: () => _shareToGmail(shareMessage),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(String message) async {
    String encodedMessage = Uri.encodeComponent(message);
    String url = 'whatsapp://send?text=$encodedMessage';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        // If WhatsApp is not installed, try web version
        String webUrl = 'https://wa.me/?text=$encodedMessage';
        if (await canLaunchUrl(Uri.parse(webUrl))) {
          await launchUrl(
            Uri.parse(webUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('WhatsApp is not available'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToTelegram(String message) async {
    String encodedMessage = Uri.encodeComponent(message);
    String url = 'tg://msg_url?url=$encodedMessage';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        // Try web version
        String webUrl = 'https://t.me/share/url?url=$encodedMessage';
        if (await canLaunchUrl(Uri.parse(webUrl))) {
          await launchUrl(
            Uri.parse(webUrl),
            mode: LaunchMode.externalApplication,
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Telegram is not available'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareToGmail(String message) async {
    String encodedMessage = Uri.encodeComponent(message);
    String subject = Uri.encodeComponent(
      'My Eco-Friendly Trip with Way2Sustain 🌱',
    );
    String url = 'mailto:?subject=$subject&body=$encodedMessage';

    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email app is not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(flex: 3, child: _buildMap()),
                _buildProgressPanel(),
              ],
            ),
          ),

          // Alert Overlay
          if (_showAlert)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: _buildAlertBanner(),
            ),

          // Celebration Confetti
          if (_showCelebration)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ConfettiPainter(
                        particles: _confettiParticles,
                        progress: _confettiAnimation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Journey Tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.from} → ${widget.to}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
                      '${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Next instruction banner
          if (_nextInstruction.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(26),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Icon(_getInstructionIcon(), color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _nextInstructionWithoutDistance,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
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
            initialCenter: widget.fromLocation,
            initialZoom: _currentZoom,
            minZoom: 5,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sustainable_travel_app',
            ),

            // Full route (gray)
            if (widget.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    color: Colors.grey,
                    strokeWidth: 4,
                  ),
                ],
              ),

            // Covered route (green)
            if (_currentPointIndex > 0)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints.sublist(
                      0,
                      _currentPointIndex + 1,
                    ),
                    color: brandGreen,
                    strokeWidth: 6,
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.fromLocation,
                  width: 40,
                  height: 40,
                  child: _buildMarker(brandGreen, Icons.location_on, 'Start'),
                ),
                Marker(
                  point: widget.toLocation,
                  width: 40,
                  height: 40,
                  child: _buildMarker(Colors.red, Icons.flag, 'End'),
                ),
                if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 50,
                    height: 70,
                    child: _buildCurrentLocationMarker(),
                  ),
              ],
            ),
          ],
        ),

        // Map Controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              _buildMapControlButton(
                icon: Icons.add,
                onPressed: () {
                  setState(() {
                    _currentZoom = (_currentZoom + 1).clamp(5.0, 18.0);
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, _currentZoom);
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.remove,
                onPressed: () {
                  setState(() {
                    _currentZoom = (_currentZoom - 1).clamp(5.0, 18.0);
                    if (_currentLocation != null) {
                      _mapController.move(_currentLocation!, _currentZoom);
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildMapControlButton(
                icon: Icons.center_focus_strong,
                onPressed: () {
                  if (_currentLocation != null) {
                    _mapController.move(_currentLocation!, _currentZoom);
                  }
                },
              ),
            ],
          ),
        ),

        // Speed overlay
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
                Icon(Icons.speed, color: brandGreen, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${(_currentSpeed * 3.6).toStringAsFixed(1)} km/h',
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

  Widget _buildMarker(Color color, IconData icon, String label) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildCurrentLocationMarker() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: brandGreen.withAlpha(
                      ((0.5 + value * 0.5) * 255).round(),
                    ),
                    blurRadius: 8 + value * 8,
                    spreadRadius: 1 + value * 3,
                  ),
                ],
              ),
              child: Icon(_getVehicleIcon(), color: Colors.white, size: 16),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_currentSpeed.toStringAsFixed(1)} m/s',
                style: const TextStyle(color: Colors.white, fontSize: 7),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(77), blurRadius: 8),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: brandGreen, size: 22),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildProgressPanel() {
    double remainingDistance = widget.totalDistance - _distanceCovered;
    int earnedPoints = (_progress * widget.ecoPoints).round();

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              const Text(
                'Progress',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF43A047),
              ),
              minHeight: 10,
            ),
          ),

          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.straighten,
                  value: _formatDistance(_distanceCovered),
                  label: 'Covered',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  value: _formatDuration(_timeElapsed),
                  label: 'Time',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.eco,
                  value: '$earnedPoints',
                  label: 'Points',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Remaining distance and ETA
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Remaining',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDistance(remainingDistance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 30, width: 1, color: Colors.grey[700]),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'ETA',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRemainingTime(),
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Control buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPaused = !_isPaused;
                    });
                  },
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _movementTimer?.cancel();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _alertMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                _showAlert = false;
              });
            },
          ),
        ],
      ),
    );
  }

  IconData _getInstructionIcon() {
    if (_nextInstruction.contains('left')) {
      return Icons.turn_left;
    } else if (_nextInstruction.contains('right')) {
      return Icons.turn_right;
    } else {
      return Icons.arrow_upward;
    }
  }

  String _formatRemainingTime() {
    double remainingTime = widget.totalDuration - _timeElapsed;
    if (remainingTime <= 0) return 'Arrived';

    int hours = (remainingTime / 3600).floor();
    int minutes = ((remainingTime % 3600) / 60).floor();

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}min';
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

class ConfettiParticle {
  Offset offset;
  Offset velocity;
  Color color;
  double size;

  ConfettiParticle({
    required this.offset,
    required this.velocity,
    required this.color,
    required this.size,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withAlpha((progress * 255).round())
        ..style = PaintingStyle.fill;

      // Update particle position based on progress
      final currentOffset = Offset(
        particle.offset.dx + particle.velocity.dx * progress * 50,
        particle.offset.dy + particle.velocity.dy * progress * 30,
      );

      // Wrap around screen
      double x = currentOffset.dx % size.width;
      double y = currentOffset.dy % size.height;

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, y),
          width: particle.size,
          height: particle.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
