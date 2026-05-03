import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveAnimationWidget extends StatefulWidget {
  final double intensity; // 1.0 = fast/high, 0.0 = slow/calm
  final Color baseColor;

  const WaveAnimationWidget({
    super.key,
    required this.intensity,
    this.baseColor = Colors.tealAccent,
  });

  @override
  State<WaveAnimationWidget> createState() => _WaveAnimationWidgetState();
}

class _WaveAnimationWidgetState extends State<WaveAnimationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant WaveAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adjust animation speed based on intensity
    // Intensity 1.0 -> 3 seconds full loop
    // Intensity 0.0 -> 15 seconds full loop
    final seconds = 15 - (widget.intensity * 12);
    _controller.duration = Duration(milliseconds: (seconds * 1000).toInt());
    if (_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            animationValue: _controller.value,
            intensity: widget.intensity,
            baseColor: widget.baseColor,
          ),
          child: Container(),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double intensity;
  final Color baseColor;

  _WavePainter({
    required this.animationValue,
    required this.intensity,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Amplitude changes with intensity
    final baseAmplitude = size.height * 0.1;
    final maxAmplitude = size.height * 0.3;
    final amplitude = baseAmplitude + (intensity * (maxAmplitude - baseAmplitude));

    _drawWave(
      canvas, 
      size, 
      amplitude: amplitude, 
      frequency: 1.5, 
      phaseShift: animationValue * 2 * math.pi, 
      color: baseColor.withOpacity(0.4), 
      offsetY: size.height * 0.6
    );

    _drawWave(
      canvas, 
      size, 
      amplitude: amplitude * 0.8, 
      frequency: 2.0, 
      phaseShift: (animationValue * 2 * math.pi) + math.pi, 
      color: baseColor.withOpacity(0.6), 
      offsetY: size.height * 0.65
    );

    _drawWave(
      canvas, 
      size, 
      amplitude: amplitude * 0.6, 
      frequency: 1.2, 
      phaseShift: (animationValue * 2 * math.pi) + (math.pi / 2), 
      color: baseColor.withOpacity(0.8), 
      offsetY: size.height * 0.7
    );
  }

  void _drawWave(Canvas canvas, Size size, {
    required double amplitude,
    required double frequency,
    required double phaseShift,
    required Color color,
    required double offsetY,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final normalizedX = x / size.width;
      final y = amplitude * math.sin((normalizedX * frequency * 2 * math.pi) + phaseShift) + offsetY;
      if (x == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || 
           oldDelegate.intensity != intensity;
  }
}
