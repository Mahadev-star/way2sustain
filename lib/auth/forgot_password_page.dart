import 'package:flutter/material.dart';
import 'package:sustainable_travel_app/auth/auth_service.dart';
import 'package:sustainable_travel_app/providers/auth_provider.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar('Please enter your email');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.resetPassword(_emailController.text);
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
      _showSnackBar('Password reset email sent!');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      body: Stack(
        children: [
          // Background gradient
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
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emailSent
                            ? 'Check your email for reset instructions'
                            : 'Enter your email to receive reset instructions',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  if (!_emailSent) ...[
                    // Email Field
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

                    const SizedBox(height: 32),

                    // Reset Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: _isLoading
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
                                'Send Reset Link',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ] else ...[
                    // Success State
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: const Color(0xFF43A047).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          // ignore: deprecated_member_use
                          color: const Color(0xFF43A047).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.mark_email_read,
                            size: 60,
                            color: Color(0xFF43A047),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Check Your Email',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'We\'ve sent password reset instructions to:',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _emailController.text,
                            style: const TextStyle(
                              color: Color(0xFF43A047),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Didn\'t receive the email? Check your spam folder or try again.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Resend Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _emailSent = false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF43A047)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text(
                          'Resend Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF43A047),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Back to login
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Back to Sign In',
                        style: TextStyle(
                          color: Color(0xFF43A047),
                          fontSize: 16,
                        ),
                      ),
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
