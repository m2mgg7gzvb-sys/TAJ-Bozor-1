import 'dart:ui';

import 'package:flutter/material.dart';

/// Стекло как на iPhone: размытие того, что под ним, полупрозрачный белый и тонкий светлый край.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.radius = 26,
    this.height,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(color: const Color(0xFF0B3B2E).withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.78),
                  Colors.white.withValues(alpha: 0.5),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
