import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/eco_points_service.dart';
import 'delete_account_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // User stats from backend
  int _totalTrips = 0;
  double _totalKm = 0.0;
  double _ecoPoints = 0.0;
  double _co2Saved = 0.0;
  int? _rank;
  bool _isLoadingStats = false;

  final EcoPointsService _ecoPointsService = EcoPointsService();

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null && !user.isGuest) {
      try {
        final userId = int.parse(user.uid);
        final profile = await _ecoPointsService.getProfile(userId);

        if (profile != null && mounted) {
          setState(() {
            _totalTrips = profile['total_trips'] ?? 0;
            _totalKm = (profile['total_km'] ?? 0).toDouble();
            _ecoPoints = (profile['eco_points'] ?? 0).toDouble();
            _co2Saved = (profile['total_co2_saved'] ?? 0).toDouble();
            _rank = profile['rank'];
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching user profile: $e');
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151717),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Choose Profile Photo",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Divider(color: Colors.grey[800]),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.blue),
              title: Text("Take Photo", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text(
                "Choose from Gallery",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_profileImage != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  "Remove Photo",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImage = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Profile photo removed"),
                      backgroundColor: Color(0xFF43A047),
                    ),
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.cancel, color: Colors.grey),
              title: Text("Cancel", style: TextStyle(color: Colors.grey)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper to get member since year
  String _getMemberSince() {
    final now = DateTime.now();
    return now.year.toString();
  }

  // Safe method to get user initials
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'U';

    final parts = trimmedName.split(' ');

    // Filter out empty parts (multiple spaces) and ensure they have content
    final validParts = parts.where((part) => part.trim().isNotEmpty).toList();

    if (validParts.isEmpty) return 'U';

    if (validParts.length == 1) {
      // Safely get first character of single word
      if (validParts[0].isEmpty) return 'U';
      return validParts[0][0].toUpperCase();
    }

    // Get first character of first two words safely
    final firstChar = validParts[0].isNotEmpty ? validParts[0][0] : '';
    final secondChar = validParts[1].isNotEmpty ? validParts[1][0] : '';

    return '$firstChar$secondChar'.toUpperCase();
  }

  // Safe method to get substring
  String _safeSubstring(String? text, int maxLength) {
    if (text == null || text.isEmpty) return 'N/A';

    final length = text.length;
    if (length == 0) return 'N/A';

    final endIndex = length < maxLength ? length : maxLength;
    if (endIndex <= 0) return 'N/A';

    return text.substring(0, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    // Get user data
    final userName = user?.displayName ?? 'User';
    final userEmail = user?.email ?? 'No email set';
    final displayName = user?.displayName ?? userName;

    // For email display - use registered email or default
    final emailDisplay = userEmail.isNotEmpty
        ? userEmail
        : 'ovmahadev@gmail.com';

    // Get initials for avatar using safe method
    final initials = _getInitials(displayName);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authProvider.signOut();
              Navigator.pushNamedAndRemoveUntil(
                // ignore: use_build_context_synchronously
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header with Camera
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // ignore: deprecated_member_use
                            color: brandGreen.withOpacity(0.2),
                            border: Border.all(color: brandGreen, width: 3),
                          ),
                          child: _profileImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(70),
                                  child: Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                    width: 140,
                                    height: 140,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: brandGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: backgroundColor,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Traveler Level: ${authProvider.isGuest ? 'Guest' : 'Registered'}",
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: brandGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: brandGreen),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "${_ecoPoints.toStringAsFixed(0)} EcoPoints",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userEmail,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showImagePickerOptions,
                    icon: Icon(
                      _profileImage != null ? Icons.edit : Icons.add_a_photo,
                      color: brandGreen,
                      size: 16,
                    ),
                    label: Text(
                      _profileImage != null
                          ? "Change Profile Photo"
                          : "Add Profile Photo",
                      style: TextStyle(color: brandGreen, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Cards
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  title: "Total Trips",
                  value: _totalTrips.toString(),
                  icon: Icons.directions_car,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: "CO₂ Saved",
                  value: "${_co2Saved.toStringAsFixed(1)} kg",
                  icon: Icons.co2,
                  color: brandGreen,
                ),
                _buildStatCard(
                  title: "Distance",
                  value: "${_totalKm.toStringAsFixed(1)} km",
                  icon: Icons.place,
                  color: Colors.purple,
                ),
                _buildStatCard(
                  title: "Rank",
                  value: _rank != null ? "#${_rank}" : "--",
                  icon: Icons.assessment,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Personal Information
            const Text(
              "Personal Information",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Email", emailDisplay, Icons.email),
            _buildInfoRow(
              "Member Since",
              _getMemberSince(),
              Icons.calendar_today,
            ),
            _buildInfoRow(
              "Account Status",
              authProvider.isGuest ? "Guest" : "Verified",
              Icons.verified_user,
            ),
            _buildInfoRow("User ID", _safeSubstring(user?.uid, 8), Icons.badge),
            const SizedBox(height: 32),

            // Account Actions
            const Text(
              "Account Actions",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.edit,
              text: "Edit Profile",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Edit profile feature coming soon"),
                    backgroundColor: Color(0xFF43A047),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.lock,
              text: "Change Password",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Change password feature coming soon"),
                    backgroundColor: Color(0xFF43A047),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // UPDATED: Delete Account button now navigates to DeleteAccountPage
            _buildActionButton(
              icon: Icons.delete,
              text: "Delete Account",
              color: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeleteAccountPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Recent Activity
            const Text(
              "Recent Activity",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAchievementCard(
              "Account Created",
              "Welcome to Way2Sustain!",
              Icons.emoji_events,
              true,
            ),
            _buildAchievementCard(
              "First Login",
              "Successfully signed in",
              Icons.login,
              authProvider.isAuthenticated,
            ),
            _buildAchievementCard(
              "Profile Complete",
              "Profile picture added",
              Icons.person_add,
              _profileImage != null,
            ),

            const SizedBox(height: 40),

            // App Info
            Center(
              child: Column(
                children: [
                  Text(
                    'Way2Sustain v1.0.0',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'User ID: ${_safeSubstring(user?.uid, 12)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? const Color(0xFF43A047), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: color ?? Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
    String title,
    String description,
    IconData icon,
    bool unlocked,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: unlocked ? Colors.green.withOpacity(0.1) : Colors.grey[900]!,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: unlocked ? Colors.green : Colors.grey[800]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unlocked
                  // ignore: deprecated_member_use
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey[800]!,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: unlocked ? Colors.green : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: unlocked ? Colors.green : Colors.grey[300],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: unlocked ? Colors.green[200] : Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.check_circle : Icons.pending,
            color: unlocked ? Colors.green : Colors.grey[600],
          ),
        ],
      ),
    );
  }
}
