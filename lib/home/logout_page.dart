import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LogoutPage extends StatelessWidget {
  const LogoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Warning Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 60),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'You will need to sign in again to access your account.',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Current User Info
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.user;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.grey[900]!.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        // ignore: deprecated_member_use
                        backgroundColor: const Color(
                          0xFF43A047,
                          // ignore: deprecated_member_use
                        ).withOpacity(0.2),
                        child: Text(
                          user?.displayName?.isNotEmpty == true
                              ? user!.displayName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? 'No email',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const Spacer(),

            // Buttons
            Column(
              children: [
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );

                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF43A047),
                          ),
                        ),
                      );

                      // Perform logout
                      await authProvider.signOut();

                      // Navigate to login
                      Navigator.pushNamedAndRemoveUntil(
                        // ignore: use_build_context_synchronously
                        context,
                        '/login',
                        (route) => false,
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Yes, Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
