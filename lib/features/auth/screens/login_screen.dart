import 'package:flutter/material.dart';
import 'package:whiteapp/core/services/api_service.dart';
import 'package:whiteapp/core/widgets/glass_text_field.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/auth/screens/signup_screen.dart';
import 'package:whiteapp/features/home/screens/home_screen.dart';
import 'package:whiteapp/features/onboarding/screens/walkthrough_screen.dart';
import 'package:whiteapp/features/recovery/services/recovery_service.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:whiteapp/core/services/social_auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const String id = 'login_screen';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late String _email;
  late String _password;
  bool _saving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: LoadingOverlay(
          isLoading: _saving,
          color: Colors.black54,
          progressIndicator: const CircularProgressIndicator(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon or Logo
                          Icon(
                            Icons.lock_person_rounded,
                            size: 80,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 32),
                          
                          // Title
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue your journey',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          // Email Field
                          GlassTextField(
                            hintText: 'Email Address',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) => _email = value,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          GlassTextField(
                            hintText: 'Password',
                            icon: Icons.lock_rounded,
                            obscureText: true,
                            onChanged: (value) => _password = value,
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          ElevatedButton(
                            onPressed: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() => _saving = true);
                              try {
                                await ApiService.login(_email, _password);
                                if (context.mounted) {
                                  final enrollments = await RecoveryService.getUserEnrollments();
                                  if (context.mounted) {
                                    setState(() => _saving = false);
                                    if (enrollments.isEmpty) {
                                      Navigator.pushReplacementNamed(context, WalkthroughScreen.id);
                                    } else {
                                      Navigator.pushReplacementNamed(context, HomeScreen.id);
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setState(() => _saving = false);
                                  _showErrorSnackBar("Login failed. Please check your email and password.");
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: Theme.of(context).primaryColor.withOpacity(0.5),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),

                          const SizedBox(height: 16),
                          
                          // Google Sign In Button
                          OutlinedButton.icon(
                            onPressed: () async {
                              setState(() => _saving = true);
                              try {
                                await SocialAuthService().googleLogin();
                                if (context.mounted) {
                                  final enrollments = await RecoveryService.getUserEnrollments();
                                  if (context.mounted) {
                                    setState(() => _saving = false);
                                    if (enrollments.isEmpty) {
                                      Navigator.pushReplacementNamed(context, WalkthroughScreen.id);
                                    } else {
                                      Navigator.pushReplacementNamed(context, HomeScreen.id);
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  setState(() => _saving = false);
                                  _showErrorSnackBar("Google Login failed: $e");
                                }
                              }
                            },
                            icon: Image.asset('assets/images/icons/google.png', height: 24),
                            label: const Text("Sign in with Google", style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Forgot Password
                          TextButton(
                            onPressed: () {
                              // TODO: Implement reset password
                            },
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),

                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, SignUpScreen.id);
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
