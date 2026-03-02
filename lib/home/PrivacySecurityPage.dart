import 'package:flutter/material.dart';

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = true;
  bool _activityStatus = true;
  bool _dataSharing = false;

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
          "Privacy & Security",
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
            _buildSectionTitle("Security"),
            _buildPrivacyTile(
              icon: Icons.lock_outline,
              title: "Two-Factor Authentication",
              subtitle: "Add an extra layer of security",
              value: _twoFactorEnabled,
              onChanged: (value) {
                setState(() {
                  _twoFactorEnabled = value;
                });
              },
            ),
            _buildPrivacyTile(
              icon: Icons.fingerprint,
              title: "Biometric Login",
              subtitle: "Use fingerprint or face ID",
              value: _biometricEnabled,
              onChanged: (value) {
                setState(() {
                  _biometricEnabled = value;
                });
              },
            ),

            const SizedBox(height: 24),

            _buildSectionTitle("Privacy"),
            _buildPrivacyTile(
              icon: Icons.visibility,
              title: "Activity Status",
              subtitle: "Show when you're active",
              value: _activityStatus,
              onChanged: (value) {
                setState(() {
                  _activityStatus = value;
                });
              },
            ),
            _buildPrivacyTile(
              icon: Icons.share,
              title: "Data Sharing",
              subtitle: "Share anonymous usage data",
              value: _dataSharing,
              onChanged: (value) {
                setState(() {
                  _dataSharing = value;
                });
              },
            ),

            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.delete_outline,
              title: "Delete Account Data",
              subtitle: "Permanently remove your data",
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),

            const SizedBox(height: 32),

            _buildSectionTitle("Connected Devices"),
            _buildDeviceTile(
              deviceName: "iPhone 13",
              deviceType: "Mobile",
              lastActive: "Active now",
              isCurrent: true,
            ),
            _buildDeviceTile(
              deviceName: "MacBook Pro",
              deviceType: "Desktop",
              lastActive: "2 hours ago",
              isCurrent: false,
            ),

            const SizedBox(height: 32),

            // Privacy Policy Links
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () {
                    // Open privacy policy
                  },
                  child: const Text(
                    "Privacy Policy",
                    style: TextStyle(color: brandGreen),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Open terms of service
                  },
                  child: const Text(
                    "Terms of Service",
                    style: TextStyle(color: brandGreen),
                  ),
                ),
              ],
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

  Widget _buildPrivacyTile({
    required IconData icon,
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
        leading: Icon(icon, color: Colors.grey[300]),
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

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.red[300]),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildDeviceTile({
    required String deviceName,
    required String deviceType,
    required String lastActive,
    required bool isCurrent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? const Color(0xFF43A047) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            deviceType == "Mobile" ? Icons.phone_iphone : Icons.computer,
            color: Colors.grey[300],
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "$deviceType • $lastActive",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: const Color(0xFF43A047).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Current",
                style: TextStyle(color: const Color(0xFF43A047), fontSize: 12),
              ),
            ),
          if (!isCurrent)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
              onPressed: () {
                // Sign out from device
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151717),
        title: const Text(
          "Delete Account Data",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "This action will permanently delete all your data and cannot be undone. Are you sure?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Delete account logic
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
