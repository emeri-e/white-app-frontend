import 'package:flutter/material.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/core/widgets/glass_text_field.dart';
import 'package:whiteapp/core/services/token_storage.dart';
import 'package:whiteapp/core/services/api_service.dart';
import '../services/buddy_service.dart';
import '../models/buddy_pairing.dart';

class BuddyAcceptScreen extends StatefulWidget {
  static const String id = 'buddy_accept_screen';
  final String? initialInviteCode;

  const BuddyAcceptScreen({super.key, this.initialInviteCode});

  @override
  State<BuddyAcceptScreen> createState() => _BuddyAcceptScreenState();
}

class _BuddyAcceptScreenState extends State<BuddyAcceptScreen> {
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  // Inline Auth Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  BuddyPairing? _inviteDetails;
  bool _showAuthForm = false;
  bool _isSignUp = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialInviteCode != null) {
      _codeController.text = widget.initialInviteCode!;
      _checkInviteDetails(widget.initialInviteCode!);
    }
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final token = await TokenStorage.getAccessToken();
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  Future<void> _checkInviteDetails(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final details = await BuddyService.checkInviteStatus(code.trim());
      setState(() {
        _inviteDetails = details;
        if (!_isLoggedIn) {
          _showAuthForm = true;
        }
      });
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inlineAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in authentication details.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        await ApiService.signup(email, password);
      }
      await ApiService.login(email, password);
      setState(() {
        _isLoggedIn = true;
        _showAuthForm = false;
      });
      _showSnackBar('Authenticated successfully! Now establish the protection PIN.');
    } catch (e) {
      _showSnackBar('Auth failed: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptInvitation() async {
    final code = _codeController.text.trim();
    final pin = _pinController.text;
    final confirmPin = _confirmPinController.text;

    if (code.isEmpty) {
      _showSnackBar('Invitation code is required.', isError: true);
      return;
    }

    if (pin.length < 4 || pin.length > 6) {
      _showSnackBar('PIN must be between 4 and 6 digits.', isError: true);
      return;
    }

    if (pin != confirmPin) {
      _showSnackBar('PINs do not match. Please try again.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BuddyService.acceptInvite(code, pin);
      _showSnackBar('Invitation accepted! Accountability session is now active. 🎉');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.withOpacity(0.9) : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.vpn_key_rounded,
          size: 64,
          color: Colors.white70,
        ),
        const SizedBox(height: 20),
        const Text(
          'Connect with Partner',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the 6-digit invitation code shared by your partner to activate the accountability bond.',
          style: TextStyle(fontSize: 14, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassTextField(
          hintText: 'Enter 6-digit invite code',
          icon: Icons.qr_code_2_rounded,
          keyboardType: TextInputType.text,
          controller: _codeController,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _checkInviteDetails(_codeController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Check Code Validity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineAuth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.account_circle_rounded, size: 64, color: Colors.white70),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? 'Create Buddy Account' : 'Buddy Login Required',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'To act as an accountability partner, you need a White App account.',
          style: TextStyle(fontSize: 14, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassTextField(
          hintText: 'Email Address',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          hintText: 'Password',
          icon: Icons.lock_rounded,
          obscureText: true,
          controller: _passwordController,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _inlineAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _isSignUp ? 'Sign Up & Continue' : 'Log In & Continue',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _isSignUp = !_isSignUp;
            });
          },
          child: Text(
            _isSignUp ? 'Already have an account? Log In' : 'Need an account? Sign Up',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptForm() {
    if (_inviteDetails == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.security_rounded, size: 64, color: Colors.greenAccent),
        const SizedBox(height: 20),
        const Text(
          'Establish Protection PIN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You are accepting protection over ${_inviteDetails!.userEmail}.\nCreate a strong 4-6 digit numeric security PIN. Your partner will need you to input this PIN to modify their filters.',
          style: const TextStyle(fontSize: 14, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassTextField(
          hintText: 'Create 4-6 digit PIN',
          icon: Icons.lock_outline_rounded,
          keyboardType: TextInputType.number,
          obscureText: true,
          controller: _pinController,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          hintText: 'Confirm Security PIN',
          icon: Icons.lock_rounded,
          keyboardType: TextInputType.number,
          obscureText: true,
          controller: _confirmPinController,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _acceptInvitation,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Accept & Enable Protection',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accept Accountability Invitation', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: LoadingOverlay(
          isLoading: _isLoading,
          color: Colors.black54,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _inviteDetails == null
                        ? _buildCodeEntry()
                        : (_showAuthForm ? _buildInlineAuth() : _buildAcceptForm()),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
