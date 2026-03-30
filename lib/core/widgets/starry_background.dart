import 'package:flutter/material.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;

  const StarryBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: child,
    );
  }
}

