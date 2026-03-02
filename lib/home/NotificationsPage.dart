import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _generalNotifications = true;
  bool _sounds = true;
  bool _vibrations = true;
  bool _badges = true;
  bool _ecoReminders = true;
  bool _challengesUpdates = true;
  bool _communityUpdates = false;
  bool _promotional = false;

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
          "Notifications",
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
            _buildSectionTitle("General"),
            _buildNotificationTile(
              title: "General Notifications",
              value: _generalNotifications,
              onChanged: (value) =>
                  setState(() => _generalNotifications = value),
            ),
            _buildNotificationTile(
              title: "Sounds",
              value: _sounds,
              onChanged: (value) => setState(() => _sounds = value),
            ),
            _buildNotificationTile(
              title: "Vibrations",
              value: _vibrations,
              onChanged: (value) => setState(() => _vibrations = value),
            ),
            _buildNotificationTile(
              title: "Badges",
              value: _badges,
              onChanged: (value) => setState(() => _badges = value),
            ),

            const SizedBox(height: 24),

            _buildSectionTitle("Notification Types"),
            _buildNotificationTile(
              title: "Eco-friendly Reminders",
              subtitle: "Daily tips and reminders",
              value: _ecoReminders,
              onChanged: (value) => setState(() => _ecoReminders = value),
            ),
            _buildNotificationTile(
              title: "Challenges & Updates",
              subtitle: "New challenges and progress",
              value: _challengesUpdates,
              onChanged: (value) => setState(() => _challengesUpdates = value),
            ),
            _buildNotificationTile(
              title: "Community Updates",
              subtitle: "Friend activity and achievements",
              value: _communityUpdates,
              onChanged: (value) => setState(() => _communityUpdates = value),
            ),
            _buildNotificationTile(
              title: "Promotional",
              subtitle: "Special offers and events",
              value: _promotional,
              onChanged: (value) => setState(() => _promotional = value),
            ),

            const SizedBox(height: 32),

            _buildSectionTitle("Quiet Hours"),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Enable Quiet Hours",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: false,
                        activeThumbColor: brandGreen,
                        onChanged: (value) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Set specific hours when you won't receive notifications",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        // Set quiet hours
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: brandGreen),
                      ),
                      child: Text(
                        "Set Quiet Hours",
                        style: TextStyle(color: brandGreen),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Send test notification
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Send Test Notification",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            : null,
        trailing: Switch(
          value: value,
          activeThumbColor: const Color(0xFF43A047),
          onChanged: onChanged,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
