import 'package:flutter/material.dart';
import 'dart:math' as math;

class CozyBackground extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;

  const CozyBackground({
    Key? key,
    required this.child,
    this.scrollController,
  }) : super(key: key);

  @override
  State<CozyBackground> createState() => _CozyBackgroundState();
}

class _CozyBackgroundState extends State<CozyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scrollOffset = 0.0;

  // Cozy dark palettes (Warm/Dark)
  final List<List<Color>> _palettes = [
    [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)], // Deep Blue/Purple
    [Color(0xFF2C061F), Color(0xFF374045), Color(0xFF222831)], // Dark Plum/Grey
    [Color(0xFF1B1B1B), Color(0xFF2D2D2D), Color(0xFF404040)], // Warm Grey
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = widget.scrollController!.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate morph factor based on scroll
    // Assuming 0 to 300 is the transition zone
    double morphFactor = (_scrollOffset / 300).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Base gradient animation
        double t = _controller.value;
        
        // Interpolate between palettes based on morphFactor
        // 0.0 -> Palette 0 (Minimal View)
        // 1.0 -> Palette 1 (Dashboard View)
        
        List<Color> currentColors;
        if (morphFactor < 0.5) {
           currentColors = _palettes[0];
        } else {
           currentColors = _palettes[1];
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: currentColors,
              transform: GradientRotation(t * math.pi / 4), // Subtle rotation
            ),
          ),
          child: Stack(
            children: [
              // Add subtle floating orbs or noise if needed for "cozy" feel
              // For now, just the gradient
              widget.child,
            ],
          ),
        );
      },
    );
  }
}
