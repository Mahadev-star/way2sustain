import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JourneyHistoryScreen extends StatefulWidget {
  const JourneyHistoryScreen({super.key});

  @override
  State<JourneyHistoryScreen> createState() => _JourneyHistoryScreenState();
}

class _JourneyHistoryScreenState extends State<JourneyHistoryScreen> {
  List<Map<String, dynamic>> _journeys = [];
  int _totalEcoPoints = 0;
  double _totalDistance = 0.0;
  double _totalCO2Saved = 0.0;

  @override
  void initState() {
    super.initState();
    _loadJourneyHistory();
  }

  Future<void> _loadJourneyHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final journeyStrings = prefs.getStringList('journey_history') ?? [];
    _journeys = journeyStrings.map((jsonStr) {
      return json.decode(jsonStr) as Map<String, dynamic>;
    }).toList();

    _totalEcoPoints = prefs.getInt('total_eco_points') ?? 0;

    for (var journey in _journeys) {
      _totalDistance += double.parse(journey['distance'] ?? '0');
      _totalCO2Saved += double.parse(journey['co2Saved'] ?? '0');
    }

    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('journey_history');
    await prefs.remove('total_eco_points');
    setState(() {
      _journeys = [];
      _totalEcoPoints = 0;
      _totalDistance = 0.0;
      _totalCO2Saved = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      appBar: AppBar(
        title: const Text(
          "Journey History",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
          if (_journeys.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Clear History"),
                    content: const Text(
                      "Are you sure you want to clear all journey history?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("CANCEL"),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearHistory();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "CLEAR",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  "Your Sustainability Impact",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      icon: Icons.workspace_premium,
                      value: _totalEcoPoints.toString(),
                      label: "Total Eco Points",
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      icon: Icons.directions,
                      value: "${_totalDistance.toStringAsFixed(1)} km",
                      label: "Distance Traveled",
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      icon: Icons.eco,
                      value: "${_totalCO2Saved.toStringAsFixed(1)} kg",
                      label: "CO₂ Saved",
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "${_journeys.length} Journeys Completed",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Journey List
          Expanded(
            child: _journeys.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, color: Colors.grey, size: 64),
                        SizedBox(height: 20),
                        Text(
                          "No journeys yet",
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Start your first journey to see it here!",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _journeys.length,
                    itemBuilder: (context, index) {
                      final journey = _journeys.reversed.toList()[index];
                      return _buildJourneyCard(journey);
                    },
                  ),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildJourneyCard(Map<String, dynamic> journey) {
    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  journey['date'] ?? 'Unknown Date',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${journey['ecoPoints']} pts",
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${journey['from']} → ${journey['to']}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "By ${journey['vehicle']}",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildJourneyStat(
                  Icons.directions,
                  "${journey['distance']} km",
                ),
                _buildJourneyStat(Icons.timer, journey['duration']),
                _buildJourneyStat(
                  Icons.fireplace,
                  "${journey['calories']} cal",
                ),
                _buildJourneyStat(Icons.eco, "${journey['co2Saved']} kg"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyStat(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
