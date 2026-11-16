import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

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
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: br,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: darkMode.value
                    ? [
                        AppColors.surface.withValues(alpha: 0.32),
                        AppColors.surface.withValues(alpha: 0.14),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.42),
                        Colors.white.withValues(alpha: 0.18),
                      ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: darkMode.value ? 0.16 : 0.6),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
