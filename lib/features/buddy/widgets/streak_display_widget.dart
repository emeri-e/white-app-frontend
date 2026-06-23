import 'dart:math';
import 'package:flutter/material.dart';

class StreakDisplayWidget extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakDisplayWidget({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  State<StreakDisplayWidget> createState() => _StreakDisplayWidgetState();
}

class _StreakDisplayWidgetState extends State<StreakDisplayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _animation = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _getNextMilestone() {
    final milestones = [7, 14, 30, 60, 90, 180, 365];
    for (var m in milestones) {
      if (widget.currentStreak < m) return m;
    }
    return 365;
  }

  bool _isMilestoneDay() {
    final milestones = [7, 14, 30, 60, 90, 180, 365];
    return milestones.contains(widget.currentStreak);
  }

  @override
  Widget build(BuildContext context) {
    final nextMilestone = _getNextMilestone();
    final progressVal = nextMilestone > 0 ? (widget.currentStreak / nextMilestone).clamp(0.0, 1.0) : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Circular background sweep
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _StreakCircularPainter(
                            progress: progressVal * _animation.value,
                            primaryColor: Theme.of(context).primaryColor,
                            trackColor: Colors.white10,
                          ),
                        ),
                      ),
                      
                      // Central flame & count
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 48,
                            color: _isMilestoneDay() ? Colors.amberAccent : Colors.orangeAccent,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.currentStreak}',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const Text(
                            'DAYS CLEAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white38,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('CURRENT STREAK', '${widget.currentStreak} Days', Colors.orangeAccent),
                  Container(width: 1, height: 32, color: Colors.white10),
                  _buildStatItem('LONGEST RECORD', '${widget.longestStreak} Days', Colors.tealAccent),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.white.withOpacity(0.03),
                  child: Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: Colors.amberAccent.withOpacity(0.8), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.currentStreak >= nextMilestone
                              ? 'Milestone fully achieved! Absolute legend! 🏆'
                              : 'Keep going! ${nextMilestone - widget.currentStreak} more days to achieve the $nextMilestone-day badge.',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StreakCircularPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color trackColor;

  _StreakCircularPainter({
    required this.progress,
    required this.primaryColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor,
          Colors.orangeAccent,
          Colors.amberAccent,
          primaryColor,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Draw active arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StreakCircularPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
