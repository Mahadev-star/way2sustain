import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
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

  Future<void> _registerUser(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar(context, 'Please fill in all fields', isError: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar(context, 'Passwords do not match', isError: true);
      return;
    }

    if (!_agreeToTerms) {
      _showSnackBar(
        context,
        'Please agree to the terms and conditions',
        isError: true,
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      _showSnackBar(
        context,
        'Password must be at least 6 characters',
        isError: true,
      );
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnackBar(
        context,
        'Please enter a valid email address',
        isError: true,
      );
      return;
    }

    try {
      await authProvider.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim().isNotEmpty
            ? _usernameController.text.trim()
            : null,
      );

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        _showSnackBar(
          context,
          'HI ${_nameController.text}, your account created successfully, go to login!',
        );
        Navigator.pop(context); // Go back to login page
      } else if (authProvider.error != null) {
        _showSnackBar(context, authProvider.error!, isError: true);
      } else {
        // Account may have been created even if there's no explicit success flag
        _showSnackBar(
          context,
          'HI ${_nameController.text}, your account created successfully, go to login!',
        );
        Navigator.pop(context); // Go back to login page
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a server error 201 (account created successfully)
        if (e.toString().contains('Server error: 201')) {
          _showSnackBar(
            context,
            'HI ${_nameController.text}, your account created successfully, go to login!',
          );
          Navigator.pop(context);
        } else {
          _showSnackBar(
            context,
            'Registration failed. Please try again.',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [Color(0xFF0A3D0A), Color(0xFF151717)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join our sustainable travel community',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    hintText: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Email Address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _usernameController,
                    hintText: 'Username (optional)',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Password (min. 6 characters)',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onVisibilityToggle: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isConfirmPasswordVisible,
                    onVisibilityToggle: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) =>
                            setState(() => _agreeToTerms = value ?? false),
                        activeColor: const Color(0xFF43A047),
                        checkColor: Colors.white,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _agreeToTerms = !_agreeToTerms),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showTermsOfServiceDialog(context),
                                    child: const Text(
                                      'Terms of Service',
                                      style: TextStyle(
                                        color: Color(0xFF43A047),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _showPrivacyPolicyDialog(context),
                                    child: const Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: Color(0xFF43A047),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => _registerUser(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43A047),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey[800], thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or sign up with',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey[800], thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _showSnackBar(
                                  context,
                                  'Google sign up is coming soon! This feature will be available in a future update.',
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.g_mobiledata,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Google',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _showSnackBar(
                                  context,
                                  'Facebook sign up is coming soon! This feature will be available in a future update.',
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.facebook,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Facebook',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Color(0xFF43A047),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      obscureText: isPassword && !isVisible,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[500],
                ),
                onPressed: onVisibilityToggle,
              )
            : null,
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF43A047), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
    );
  }
}
