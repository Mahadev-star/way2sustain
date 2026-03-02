import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/eco_points_service.dart';

class MyTripsPage extends StatefulWidget {
  const MyTripsPage({super.key});

  @override
  State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
  final EcoPointsService _ecoPointsService = EcoPointsService();
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  // Stats
  int _totalTrips = 0;
  double _totalDistance = 0.0;
  double _totalCo2Saved = 0.0;

  // Image loading states
  Map<String, bool> _imageLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null && !user.isGuest) {
      try {
        final userId = int.parse(user.uid);
        final trips = await _ecoPointsService.getTrips(userId);

        if (trips != null && mounted) {
          setState(() {
            _trips = trips;
            _totalTrips = trips.length;
            _totalDistance = trips.fold(
              0.0,
              (sum, trip) => sum + (trip['distance'] ?? 0.0),
            );
            _totalCo2Saved = trips.fold(
              0.0,
              (sum, trip) => sum + (trip['co2_saved'] ?? 0.0),
            );
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  IconData _getTransportIcon(String routeType) {
    switch (routeType.toLowerCase()) {
      case 'eco':
        return Icons.directions_bike;
      case 'balanced':
        return Icons.directions_bus;
      case 'normal':
        return Icons.directions_car;
      default:
        return Icons.directions_walk;
    }
  }

  Color _getTransportColor(String routeType) {
    switch (routeType.toLowerCase()) {
      case 'eco':
        return Colors.green;
      case 'balanced':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tripDate = DateTime(date.year, date.month, date.day);

    if (tripDate == today) {
      return 'Today';
    } else if (tripDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "My Trips",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stats Overview
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: brandGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    // ignore: deprecated_member_use
                    border: Border.all(color: brandGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTotalStat(
                        "Total Trips",
                        _totalTrips.toString(),
                        Icons.list,
                      ),
                      _buildTotalStat(
                        "Total Distance",
                        "${_totalDistance.toStringAsFixed(1)} km",
                        Icons.map,
                      ),
                      _buildTotalStat(
                        "CO₂ Saved",
                        "${_totalCo2Saved.toStringAsFixed(1)} kg",
                        Icons.eco,
                      ),
                    ],
                  ),
                ),

                // Trips List
                Expanded(
                  child: _trips.isEmpty
                      ? const Center(
                          child: Text(
                            'No trips yet',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _trips.length,
                          itemBuilder: (context, index) {
                            final trip = _trips[index];
                            return _buildTripCard(trip);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to new trip planning
        },
        backgroundColor: brandGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTotalStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final date = DateTime.parse(trip['date']);
    final formattedDate = _formatDate(date);
    final routeType = trip['route_type'] ?? 'normal';
    final transportIcon = _getTransportIcon(routeType);
    final transportColor = _getTransportColor(routeType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: const Color(0xFF43A047).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "${trip['eco_points'] ?? 0} pts",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: transportColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(transportIcon, color: transportColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip['start_location'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        height: 20,
                        width: 1,
                        color: Colors.grey[700],
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip['end_location'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.grey, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "${(trip['distance'] ?? 0.0).toStringAsFixed(1)} km",
                        style: TextStyle(color: Colors.grey[300], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.co2, color: Colors.green, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "${(trip['co2_saved'] ?? 0.0).toStringAsFixed(1)} kg",
                        style: TextStyle(
                          color: Colors.green[300],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.grey, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.details, color: Colors.grey, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
