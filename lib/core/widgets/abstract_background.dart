import 'package:flutter/material.dart';

class AbstractBackground extends StatelessWidget {
  final Widget child;
  final double scrollProgress;

  const AbstractBackground({
    Key? key,
    required this.child,
    this.scrollProgress = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: child,
    );
  }
}

