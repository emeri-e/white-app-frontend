import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashAnimation extends StatefulWidget {
  final String appName;
  final VoidCallback? onComplete;

  const SplashAnimation({
    super.key,
    this.appName = 'whiteapp',
    this.onComplete,
  });

  @override
  State<SplashAnimation> createState() => _SplashAnimationState();
}

class _SplashAnimationState extends State<SplashAnimation> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _shimmerController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<int> _characterCount;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    // Logo: gentle scale-up with fade
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    // Text: typing effect after logo settles
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _characterCount = IntTween(begin: 0, end: widget.appName.length).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.3, curve: Curves.easeIn)),
    );

    // Shimmer for the glow ring
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Sequence: logo → text
    _logoController.forward().then((_) {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        _textController.forward();
      });
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = screenWidth * 0.28; // Contained, not overflowing

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo with glow ring
            AnimatedBuilder(
              animation: Listenable.merge([_logoController, _shimmerController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value.clamp(0.0, 1.0),
                    child: Container(
                      width: logoSize + 32,
                      height: logoSize + 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(
                              0.15 + 0.1 * _shimmerController.value,
                            ),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1.5,
                          ),
                        ),
                        child: Image.asset(
                          'assets/icon_no_bg.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // App name with typing effect
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                final text = widget.appName.substring(0, _characterCount.value);
                final cursorVisible = _characterCount.value < widget.appName.length;
                return Opacity(
                  opacity: _textOpacity.value.clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      // Blinking cursor effect during typing
                      if (cursorVisible)
                        AnimatedOpacity(
                          opacity: (_shimmerController.value > 0.5) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 100),
                          child: Text(
                            '|',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Subtle tagline that fades in with text
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                final progress = _textController.value;
                return Opacity(
                  opacity: (progress > 0.7) ? ((progress - 0.7) / 0.3).clamp(0.0, 1.0) : 0.0,
                  child: Text(
                    'Your recovery journey',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white38,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
