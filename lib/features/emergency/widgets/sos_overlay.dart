import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/emergency/services/emergency_service.dart';

class SOSOverlay extends StatefulWidget {
  const SOSOverlay({super.key});

  @override
  State<SOSOverlay> createState() => _SOSOverlayState();
}

class _SOSOverlayState extends State<SOSOverlay> {
  final EmergencyService _emergencyService = EmergencyService();
  int _remainingSos = 0;
  bool _isPremium = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await _emergencyService.getSOSStatus();
      setState(() {
        _remainingSos = status['remaining_sos'] ?? 0;
        _isPremium = status['is_premium'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blur background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IMMEDIATE HELP',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are not alone. Choose how we can support you right now.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    _buildSOSOption(
                      context,
                      title: 'Community Support',
                      subtitle: _isPremium 
                        ? 'Unlimited urgent requests enabled' 
                        : '$_remainingSos requests remaining today',
                      icon: Icons.people_alt_rounded,
                      color: Colors.orangeAccent,
                      isDisabled: !_isPremium && _remainingSos <= 0,
                      onTap: () => _handleCommunitySupport(context),
                      isPremium: _isPremium,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSOSOption(
                      context,
                      title: 'Instant Session',
                      subtitle: 'Speak with an available therapist now',
                      icon: Icons.video_call_rounded,
                      color: Colors.greenAccent,
                      onTap: () => _handleInstantSession(context),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSOSOption(
                      context,
                      title: 'Expert Gateway',
                      subtitle: 'Message your assigned supervisor',
                      icon: Icons.verified_user_rounded,
                      color: Colors.blueAccent,
                      onTap: () => _handleSupervisorGateway(context),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildSOSOption(
                      context,
                      title: 'Relief Tools',
                      subtitle: 'Breathing, grounding & coping exercises',
                      icon: Icons.spa_rounded,
                      color: Colors.purpleAccent,
                      onTap: () => _handleReliefTools(context),
                    ),
                    
                    const SizedBox(height: 40),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
    bool isPremium = false,
  }) {
    final finalColor = isDisabled ? Colors.grey : color;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            finalColor.withOpacity(0.2),
            finalColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: finalColor.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: finalColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: finalColor, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                ),
                                child: Text(
                                  'PREMIUM',
                                  style: GoogleFonts.outfit(
                                    color: Colors.amber,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDisabled ? 'Daily limit reached. Upgrade to Premium.' : subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(isDisabled ? Icons.lock_rounded : Icons.arrow_forward_ios_rounded, color: finalColor, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleCommunitySupport(BuildContext context) {
    // Show SOS Post Screen
    Navigator.pop(context);
    Navigator.pushNamed(context, 'sos_post_screen');
  }

  void _handleInstantSession(BuildContext context) {
    // Show Specialist Directory
    Navigator.pop(context);
    Navigator.pushNamed(context, 'specialist_directory_screen');
  }

  void _handleSupervisorGateway(BuildContext context) {
    // Show Supervisor Chat
    Navigator.pop(context);
    Navigator.pushNamed(context, 'supervisor_chat_screen');
  }

  void _handleReliefTools(BuildContext context) {
    Navigator.pop(context);
    Navigator.pushNamed(context, 'tools_hub_screen');
  }
}
