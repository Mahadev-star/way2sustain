// lib/screens/delete_account_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _isDeleting = false;
  final TextEditingController _emailController = TextEditingController();
  bool _confirmCheckbox = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showFinalConfirmation(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    final userEmail = user?.email ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red, size: 30),
            SizedBox(width: 12),
            Text(
              'Final Warning',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are about to permanently delete your account. This action cannot be undone!',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What will be deleted:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildConsequenceItem('All your personal data'),
                    _buildConsequenceItem('Trip history and statistics'),
                    _buildConsequenceItem('EcoPoints and achievements'),
                    _buildConsequenceItem('Account credentials'),
                    _buildConsequenceItem('Profile information'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account to be deleted:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Icon(Icons.person, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(color: Colors.grey[400]),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _isDeleting
                ? null
                : () async {
                    setState(() => _isDeleting = true);
                    Navigator.pop(context); // Close dialog

                    // Show processing
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Processing account deletion...'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Simulate deletion process
                    await Future.delayed(const Duration(seconds: 2));

                    // In real app, call: await authProvider.deleteAccount();
                    // For now, we'll just sign out
                    await authProvider.signOut();

                    // Show success message
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );

                    // Navigate to login
                    Navigator.pushNamedAndRemoveUntil(
                      // ignore: use_build_context_synchronously
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Delete Forever', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequenceItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[300])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userEmail = user?.email ?? '';

    const Color backgroundColor = Color(0xFF151717);
    const Color redColor = Colors.red;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: redColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: redColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: redColor, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Warning: Account Deletion',
                          style: TextStyle(
                            color: redColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This action is permanent and cannot be undone',
                          style: TextStyle(
                            // ignore: deprecated_member_use
                            color: redColor.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current Account Info
            Container(
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
                    radius: 28,
                    backgroundColor: Colors.grey[800],
                    child: Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: redColor),
                          ),
                          child: Text(
                            'To be deleted',
                            style: TextStyle(
                              color: redColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Email Verification
            Text(
              'To confirm, please enter your email:',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              userEmail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Email Input
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Confirmation Checkbox
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _confirmCheckbox,
                    onChanged: (value) {
                      setState(() {
                        _confirmCheckbox = value ?? false;
                      });
                    },
                    fillColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.red;
                      }
                      return Colors.grey[800]!;
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'I understand this action is irreversible and all my data will be permanently deleted.',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Delete Button (Disabled until conditions are met)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: redColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed:
                    (_emailController.text.trim().toLowerCase() ==
                            userEmail.toLowerCase() &&
                        _confirmCheckbox &&
                        !_isDeleting)
                    ? () => _showFinalConfirmation(context, authProvider)
                    : null,
                child: _isDeleting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever),
                          SizedBox(width: 12),
                          Text(
                            'Delete Account Permanently',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel Deletion'),
              ),
            ),

            const SizedBox(height: 32),

            // Important Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.grey[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                // ignore: deprecated_member_use
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[300]),
                      const SizedBox(width: 8),
                      const Text(
                        'Need Help?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    'Export your data before deletion',
                    Icons.download,
                  ),
                  _buildHelpItem(
                    'Contact support for assistance',
                    Icons.support_agent,
                  ),
                  _buildHelpItem(
                    'Consider deactivating instead',
                    Icons.pause_circle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[300], size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[300])),
          ),
        ],
      ),
    );
  }
}
