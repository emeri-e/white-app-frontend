import 'dart:math' as math;
import 'package:flutter/material.dart';

class AbstractBackground extends StatefulWidget {
  final Widget child;
  final double scrollProgress; // 0.0 (Minimal) -> 1.0 (Dashboard)

  const AbstractBackground({
    Key? key,
    required this.child,
    this.scrollProgress = 0.0,
  }) : super(key: key);

  @override
  State<AbstractBackground> createState() => _AbstractBackgroundState();
}

class _AbstractBackgroundState extends State<AbstractBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _introController;
  final List<_Star> _stars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    // Generate stars
    for (int i = 0; i < 100; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        opacity: _random.nextDouble(),
        pulseSpeed: _random.nextDouble() * 2 + 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep Black Background
        Container(color: const Color(0xFF050505)),
        
        // Animated Custom Painter
        AnimatedBuilder(
          animation: Listenable.merge([_controller, _introController]),
          builder: (context, child) {
            return CustomPaint(
              painter: _AbstractPainter(
                animationValue: _controller.value,
                introValue: _introController.value,
                stars: _stars,
                scrollProgress: widget.scrollProgress,
              ),
              size: Size.infinite,
            );
          },
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class _Star {
  double x;
  double y;
  double size;
  double opacity;
  double pulseSpeed;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.pulseSpeed,
  });
}

class _AbstractPainter extends CustomPainter {
  final double animationValue;
  final double introValue;
  final List<_Star> stars;
  final double scrollProgress;

  _AbstractPainter({
    required this.animationValue,
    required this.introValue,
    required this.stars,
    required this.scrollProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Stars
    final starPaint = Paint()..color = Colors.white;
    for (var star in stars) {
      // Pulse effect
      double pulse = (math.sin(animationValue * math.pi * 2 * star.pulseSpeed) + 1) / 2;
      double currentOpacity = (star.opacity + pulse * 0.5).clamp(0.0, 1.0);
      
      starPaint.color = Colors.white.withOpacity(currentOpacity * 0.8);
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size * (0.8 + pulse * 0.4),
        starPaint,
      );
    }

    // 2. Draw Abstract Object
    // Intro Animation:
    // introValue 0.0 -> 1.0
    // Wave Amplitude: High -> Low (0)
    // Position Y: Bottom (height) -> Target (height * 0.75)
    
    // Scroll Interaction:
    // scrollProgress 0.0 (Minimal) -> 1.0 (Dashboard)
    // At 0.0: Use Intro Target Position (height * 0.75)
    // At 1.0: Move to Bottom Right (width, height)
    
    // Calculate Base Position (Minimal View Target)
    final minimalX = size.width / 2;
    final minimalY = size.height * 0.85; // Target position beneath quote
    
    // Apply Intro to Minimal Y
    // Start at height + radius (offscreen) or just height?
    // User said "brought up".
    final startY = size.height * 0.9;
    final currentMinimalY = startY + (minimalY - startY) * CurvedAnimation(parent: AlwaysStoppedAnimation(introValue), curve: Curves.easeOut).value;

    // Calculate Dashboard Position
    final dashboardX = size.width;
    final dashboardY = size.height;

    // Interpolate based on scrollProgress
    final currentX = minimalX + (dashboardX - minimalX) * scrollProgress;
    final currentY = currentMinimalY + (dashboardY - currentMinimalY) * scrollProgress;

    final center = Offset(currentX, currentY);
    final maxRadius = math.min(size.width, size.height) * 0.4; // Smaller radius to fit
    
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Wave Amplitude
    // Intro: 1.0 -> 0.0 (becomes circle)
    // Scroll: 0.0 -> ? (maybe stays circle or becomes wavy again?)
    // User said "reduce until it reachs the circle".
    // Let's say at Minimal (scroll 0), it's a circle (amplitude 0).
    // At Dashboard (scroll 1), maybe it's wavy again? Or stays circle?
    // Let's keep it simple: It's a circle at Minimal.
    
    double baseAmplitude = 20.0;
    double introAmplitudeFactor = 1.0 - CurvedAnimation(parent: AlwaysStoppedAnimation(introValue), curve: Curves.easeInOut).value;
    
    // If scrollProgress > 0, maybe we increase amplitude again?
    // Let's just use the intro factor for now.
    double amplitude = baseAmplitude * introAmplitudeFactor;
    
    // Add scroll effect: As we scroll to dashboard, maybe it morphs?
    // Let's keep it as is for now.

    for (int i = 0; i < 15; i++) {
      // Quadratic spacing: radius increases more with each step
      // Base radius + (step * i) + (growth_factor * i * i)
      double radius = 20.0 + (i * 10.0) + (i * i * 1.6);
      
      if (radius > math.max(size.width, size.height) * 1.5) break;

      // Color
      Color color = Color.lerp(
        Colors.blueAccent.withOpacity(0.3),
        Colors.purpleAccent.withOpacity(0.3),
        (math.sin(animationValue * math.pi * 2 + i * 0.5) + 1) / 2,
      )!;
      
      linePaint.color = color;
      linePaint.strokeWidth = 2.0;

      // Draw
      Path path = Path();
      for (double angle = 0; angle <= math.pi * 2; angle += 0.1) {
        double distortion = math.sin(angle * 6 + animationValue * math.pi * 2 + i) * amplitude;
        double r = radius + distortion;
        
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AbstractPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.introValue != introValue ||
           oldDelegate.scrollProgress != scrollProgress;
  }
}
