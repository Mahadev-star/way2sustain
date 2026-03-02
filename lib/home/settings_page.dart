import 'package:flutter/material.dart';
import 'package:sustainable_travel_app/home/EditProfilePage.dart';
import 'package:sustainable_travel_app/home/LanguagePage.dart';
import 'package:sustainable_travel_app/home/NotificationsPage.dart';
import 'package:sustainable_travel_app/home/AboutPage.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = true;

  // Privacy Policy Content
  final String _privacyPolicy = '''
📜 Privacy Policy (Way2Sustain)

1️⃣ Data Collection
Way2Sustain may collect:
• Location data (for route calculation)
• Device information
• Route preferences (transport mode: car, EV, bus, cycle, walk)

2️⃣ Use of Data
Collected data is used only to:
• Calculate sustainable routes
• Estimate emissions
• Improve AI prediction models
• Enhance user experience

3️⃣ Data Storage
User data is stored securely and is not shared with third parties unless required by law.

4️⃣ No Sale of Personal Data
Way2Sustain does not sell, rent, or trade personal user data to advertisers or third-party organizations.

5️⃣ User Rights
Users have the right to:
• Request deletion of their data
• Disable location tracking
• Contact support for privacy-related concerns
''';

  // Terms of Service Content
  final String _termsOfService = '''
📜 Terms of Service (Way2Sustain)

1️⃣ Acceptance of Terms
By using Way2Sustain, users agree to comply with all terms and conditions stated in this agreement. If you do not agree, please discontinue use of the application.

2️⃣ Purpose of the Application
Way2Sustain provides eco-friendly route recommendations based on traffic prediction, emissions estimation, air quality index (AQI), and sustainability metrics. The app is intended for informational and educational purposes only.

3️⃣ Accuracy of Information
While Way2Sustain uses AI-based algorithms such as Ant Colony Optimization (ACO) to generate sustainable routes, we do not guarantee 100% accuracy of traffic data, emissions data, or air quality predictions. Users are responsible for verifying route safety and road conditions.

4️⃣ User Responsibilities
Users must:
• Provide accurate location information
• Follow local traffic rules and regulations
• Use the app responsibly without attempting to misuse or disrupt its services

5️⃣ Limitation of Liability
Way2Sustain is not liable for:
• Traffic violations
• Delays
• Accidents
• Route inaccuracies

Use of the application is at the user's own risk.
''';

  // Help Center Content
  final String _helpCenterContent = '''
🗺 How to Use the Map

Welcome to Way2Sustain! Here's a quick guide on how to use the map feature:

1️⃣ Setting Your Destination
• Enter your destination in the search bar
• You can also select from saved locations or recent destinations

2️⃣ Choosing Route Type
• 🌱 Eco Route: Maximizes sustainability, prioritizes lower emissions
• ⚖ Balanced Route: Equal consideration of time and environmental impact
• 🚗 Normal Route: Fastest route with minimal stops

3️⃣ Transport Mode
Select your preferred transport mode:
• 🚗 Car
• ⚡ Electric Vehicle (EV)
• 🚌 Bus
• 🚴 Cycle
• 🚶 Walk

4️⃣ Viewing Route Details
• Estimated time and distance
• Carbon emissions comparison
• Air Quality Index (AQI) along the route
• EV charging stations (for EV mode)

5️⃣ Start Navigation
• Once you've chosen your route, tap "Start" to begin navigation
• The app will provide turn-by-turn directions

6️⃣ Eco Tips
• During your journey, you'll receive eco-friendly tips
• Earn eco points for sustainable choices

💡 Pro Tips:
• Use Eco mode regularly to minimize your carbon footprint
• Check the AQI before traveling to plan accordingly
• Compare different routes to see the environmental impact
''';

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
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Settings
            _buildSectionTitle("Account"),
            _buildSettingTile(
              icon: Icons.person,
              title: "Edit Profile",
              subtitle: "Update your personal information",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.notifications_active,
              title: "Notifications",
              trailing: Switch(
                value: notificationsEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // App Settings
            _buildSectionTitle("App Settings"),
            _buildSettingTile(
              icon: Icons.dark_mode,
              title: "Dark Mode",
              trailing: Switch(
                value: darkModeEnabled,
                activeThumbColor: brandGreen,
                onChanged: (value) {
                  setState(() {
                    darkModeEnabled = value;
                  });
                },
              ),
            ),
            _buildSettingTile(
              icon: Icons.language,
              title: "Language",
              subtitle: "English",
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LanguagePage()),
                );
              },
            ),
            _buildSettingTile(
              icon: Icons.info_outline,
              title: "About",
              subtitle: "App information and developers",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                );
              },
            ),

            const SizedBox(height: 24),

            // Support
            _buildSectionTitle("Support"),
            _buildSettingTile(
              icon: Icons.help_outline,
              title: "Help Center",
              subtitle: "How to use the map",
              onTap: () {
                _showHelpCenterDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.feedback_outlined,
              title: "Send Feedback",
              subtitle: "Share your suggestions",
              onTap: () {
                _showSendFeedbackDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.privacy_tip_outlined,
              title: "Privacy Policy",
              onTap: () {
                _showPrivacyPolicyDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.description_outlined,
              title: "Terms of Service",
              onTap: () {
                _showTermsOfServiceDialog(context);
              },
            ),

            const SizedBox(height: 24),

            // Account Actions
            _buildSectionTitle("Account Actions"),
            _buildSettingTile(
              icon: Icons.logout,
              title: "Log Out",
              titleColor: Colors.orange,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
            _buildSettingTile(
              icon: Icons.delete_outline,
              title: "Delete Account",
              titleColor: Colors.red,
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),

            const SizedBox(height: 32),

            // App Version
            Center(
              child: Column(
                children: [
                  Text(
                    "Way2Sustain v1.0.0",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Build 2024.01.01",
                    style: TextStyle(color: Colors.grey[700], fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    final Color primaryColor = titleColor ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        // ignore: deprecated_member_use
        leading: Icon(icon, color: primaryColor.withOpacity(0.9)),
        title: Text(
          title,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
                : null),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        visualDensity: const VisualDensity(vertical: 0),
      ),
    );
  }

  void _showHelpCenterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text(
              "Help Center",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _helpCenterContent,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Color(0xFF43A047)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.feedback_outlined, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text(
              "Send Feedback",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We'd love to hear your feedback, suggestions, or report any issues!",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              "Email us at:",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: 'way2sustain.offficial@gmail.com',
                  query: 'subject=Way2Sustain Feedback',
                );
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                }
              },
              child: const Text(
                "way2sustain.offficial@gmail.com",
                style: TextStyle(
                  color: Color(0xFF43A047),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text(
              "Privacy Policy",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _privacyPolicy,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Color(0xFF43A047)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsOfServiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.description_outlined, color: Color(0xFF43A047)),
            SizedBox(width: 8),
            Text(
              "Terms of Service",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            _termsOfService,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Close",
              style: TextStyle(color: Color(0xFF43A047)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Log Out",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "Log Out",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Delete Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This action cannot be undone. All your data will be permanently deleted including:",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 12),
            _buildBulletPoint("Your profile information"),
            _buildBulletPoint("Sustainability progress"),
            _buildBulletPoint("Challenges and achievements"),
            _buildBulletPoint("Community interactions"),
            SizedBox(height: 16),
            Text(
              "Are you absolutely sure?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "Delete Account",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: camel_case_types
class _buildBulletPoint extends StatelessWidget {
  final String text;

  const _buildBulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, right: 8),
            child: Icon(Icons.circle, size: 6, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
