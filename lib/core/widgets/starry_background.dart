import 'dart:math';
import 'package:flutter/material.dart';

class StarryBackground extends StatefulWidget {
  final Widget child;
  const StarryBackground({super.key, required this.child});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Generate stars
    for (int i = 0; i < 70; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2 + 1,
        opacity: _random.nextDouble(),
        speed: _random.nextDouble() * 0.2 + 0.05, // Increased speed significantly
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dark Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F172A), // Slate 900
                Color(0xFF1E293B), // Slate 800
                Color(0xFF334155), // Slate 700
              ],
            ),
          ),
        ),
        // Animated Stars
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: StarPainter(_stars, _controller.value),
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

class Star {
  double x;
  double y;
  double size;
  double opacity;
  double speed;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
  });
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      // Twinkle effect
      double opacity =
          (star.opacity + sin(animationValue * 2 * pi + star.x * 10)) / 2 + 0.3;
      paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));

      // Move stars slightly
      double y = (star.y + animationValue * star.speed) % 1.0;

      canvas.drawCircle(
        Offset(star.x * size.width, y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
