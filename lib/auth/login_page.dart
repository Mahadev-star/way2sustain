import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF43A047),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  Future<void> _loginWithEmail(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar(context, 'Please fill in all fields');
      return;
    }

    try {
      await authProvider.loginWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        if (authProvider.error != null) {
          _showSnackBar(context, 'Error: ${authProvider.error}');
        } else if (authProvider.isAuthenticated) {
          _showSnackBar(context, 'Login successful!');
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showSnackBar(context, 'Login failed. Please check credentials.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Login error: $e');
      }
    }
  }

  Future<void> _loginWithGoogle(BuildContext context) async {
    _showSnackBar(
      context,
      'Google login is coming soon! This feature will be available in a future update.',
    );
  }

  Future<void> _loginWithFacebook(BuildContext context) async {
    _showSnackBar(
      context,
      'Facebook login is coming soon! This feature will be available in a future update.',
    );
  }

  Future<void> _loginAsGuest(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.loginAsGuest();

      if (mounted) {
        if (authProvider.error != null) {
          _showSnackBar(context, authProvider.error!);
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Guest login failed. Please try again.');
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
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue your sustainable journey',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email Address',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: Colors.grey[500],
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF43A047),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.grey[500],
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF43A047),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF43A047),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => _loginWithEmail(context),
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
                              'Login',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF43A047)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text(
                        'Create New Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF43A047),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey[800], thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or continue with',
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
                              : () => _loginWithGoogle(context),
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
                              : () => _loginWithFacebook(context),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => _loginAsGuest(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Continue as Guest',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'By continuing, you agree to our',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _showTermsOfServiceDialog(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: Color(0xFF43A047),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Text(
                              ' and ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _showPrivacyPolicyDialog(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: Color(0xFF43A047),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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
}
