import 'package:flutter/material.dart';

class CozyBackground extends StatelessWidget {
  final Widget child;
  final ScrollController? scrollController;

  const CozyBackground({
    Key? key,
    required this.child,
    this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: child,
    );
  }
}

