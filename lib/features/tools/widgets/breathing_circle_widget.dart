import 'package:flutter/material.dart';

class BreathingCircleWidget extends StatelessWidget {
  final String phase; // 'Inhale', 'Hold', 'Exhale'
  final double scale;
  final Duration duration;
  final Color baseColor;

  const BreathingCircleWidget({
    super.key,
    required this.phase,
    required this.scale,
    required this.duration,
    this.baseColor = Colors.lightBlueAccent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOutSine, // Smooth breathing curve
      width: 150 * scale,
      height: 150 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withOpacity(0.8),
            baseColor.withOpacity(0.2),
            Colors.transparent,
          ],
          stops: const [0.5, 0.8, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.4),
            blurRadius: 30 * scale,
            spreadRadius: 10 * scale,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 80 * scale,
          height: 80 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withOpacity(0.3),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}
