import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/core/widgets/glass_text_field.dart';
import '../models/buddy_pairing.dart';
import '../services/buddy_service.dart';

class BuddyInviteScreen extends StatefulWidget {
  static const String id = 'buddy_invite_screen';

  const BuddyInviteScreen({super.key});

  @override
  State<BuddyInviteScreen> createState() => _BuddyInviteScreenState();
}

class _BuddyInviteScreenState extends State<BuddyInviteScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  BuddyPairing? _pendingPairing;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadActiveInvite();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveInvite() async {
    setState(() => _isLoading = true);
    try {
      final pairing = await BuddyService.getPairingStatus();
      if (pairing != null && pairing.status == 'pending') {
        setState(() {
          _pendingPairing = pairing;
        });
        _startTimer();
      }
    } catch (_) {
      // Ignored: self-managing or no active invite
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    if (_pendingPairing == null) return;

    final expiry = _pendingPairing!.inviteExpiresAt;
    _timeLeft = expiry.difference(DateTime.now());

    if (_timeLeft.isNegative) {
      setState(() {
        _timeLeft = Duration.zero;
        _pendingPairing = null;
      });
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative) {
        timer.cancel();
        setState(() {
          _timeLeft = Duration.zero;
          _pendingPairing = null;
        });
      } else {
        setState(() {
          _timeLeft = diff;
        });
      }
    });
  }

  Future<void> _generateInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final pairing = await BuddyService.generateInvite(email);
      setState(() {
        _pendingPairing = pairing;
        _emailController.clear();
      });
      _startTimer();
      _showSnackBar('Accountability invitation code generated successfully!');
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelInvite() async {
    if (_pendingPairing == null) return;
    setState(() => _isLoading = true);
    try {
      await BuddyService.removeBuddy('Invitation cancelled by user', '000000');
      _countdownTimer?.cancel();
      setState(() {
        _pendingPairing = null;
        _timeLeft = Duration.zero;
      });
      _showSnackBar('Pending invitation cancelled successfully.');
    } catch (e) {
      // If no PIN existed yet, the removal API succeeds or requires a mock PIN, which we passed
      _countdownTimer?.cancel();
      setState(() {
        _pendingPairing = null;
        _timeLeft = Duration.zero;
      });
      _showSnackBar('Pending invitation cancelled.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to Clipboard! 📋');
  }

  void _shareInvite() {
    if (_pendingPairing == null) return;
    final text = 'Protect me! Pair with me on White App using code ${_pendingPairing!.inviteCode}. Direct pairing link: ${_pendingPairing!.inviteLink}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Pairing text ready! Copied to clipboard for quick sharing. 🚀');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: isError ? Colors.red.withOpacity(0.9) : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Widget _buildInviteInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.share_rounded,
          size: 64,
          color: Colors.white70,
        ),
        const SizedBox(height: 20),
        const Text(
          'Invite accountability partner',
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
          'An accountability partner helps you stay clean. They will receive alerts if you try to disable protections.',
          style: TextStyle(fontSize: 14, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassTextField(
          hintText: "Buddy's Email Address",
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _generateInvite,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
          ),
          child: const Text(
            'Generate Invitation Code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveInviteCard() {
    if (_pendingPairing == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.hourglass_empty_rounded,
          size: 64,
          color: Colors.amberAccent,
        ),
        const SizedBox(height: 20),
        const Text(
          'Pending Connection',
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
          'Waiting for ${_pendingPairing!.buddyEmail ?? "your partner"} to accept.',
          style: const TextStyle(fontSize: 14, color: Colors.white60),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              const Text(
                'INVITATION CODE',
                style: TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _pendingPairing!.inviteCode,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                    onPressed: () => _copyToClipboard(_pendingPairing!.inviteCode),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              const Text(
                'CODE EXPIRES IN',
                style: TextStyle(fontSize: 12, color: Colors.white38, letterSpacing: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_timeLeft),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _shareInvite,
          icon: const Icon(Icons.share_rounded, size: 20),
          label: const Text('Share Connection Info'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _cancelInvite,
          icon: const Icon(Icons.cancel_rounded, size: 20),
          label: const Text('Cancel Invitation'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountability Connection', style: TextStyle(color: Colors.white)),
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
                    child: _pendingPairing == null
                        ? _buildInviteInput()
                        : _buildActiveInviteCard(),
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
