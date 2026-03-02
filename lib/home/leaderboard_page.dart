import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/eco_points_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final EcoPointsService _ecoPointsService = EcoPointsService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _leaderboard = [];
  Map<String, dynamic>? _currentUserRank;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      // Get leaderboard data
      final data = await _ecoPointsService.getLeaderboard();

      // Get current user's rank
      final userIdStr = await _secureStorage.read(key: 'current_user_id');
      if (userIdStr != null) {
        final userId = int.parse(userIdStr);
        final rankData = await _ecoPointsService.getUserRank(userId);
        if (mounted) {
          setState(() {
            _leaderboard = data ?? [];
            _currentUserRank = rankData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _leaderboard = data ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: Column(
                children: [
                  // Current user rank card
                  if (_currentUserRank != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(26),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '#${_currentUserRank!['rank']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Your Rank',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${_currentUserRank!['eco_points']} Eco Points',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 32,
                          ),
                        ],
                      ),
                    ),

                  // Leaderboard list
                  Expanded(
                    child: _leaderboard.isEmpty
                        ? const Center(
                            child: Text(
                              'No users yet',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _leaderboard.length,
                            itemBuilder: (context, index) {
                              final user = _leaderboard[index];
                              return _buildLeaderboardItem(user, index + 1);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int rank) {
    Color rankColor;
    IconData? medal;

    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      medal = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      medal = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      medal = Icons.emoji_events;
    } else {
      rankColor = Colors.white70;
      medal = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank <= 3 ? rankColor.withAlpha(77) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rankColor.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: medal != null
                  ? Icon(medal, color: rankColor, size: 20)
                  : Text(
                      '$rank',
                      style: TextStyle(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['username'] ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${user['total_trips']} trips',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user['eco_points']}',
                style: const TextStyle(
                  color: Color(0xFF43A047),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Text(
                'points',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
