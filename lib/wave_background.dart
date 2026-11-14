import 'package:flutter/material.dart';

import 'theme.dart';

/// Фон главных экранов: светлый, с мягкими зелёными волнами в верхнем правом и нижнем левом углах.
class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFF2F7F5)),
            child: CustomPaint(painter: _WavePainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Верхняя волна справа.
    final top = Path()
      ..moveTo(w * 0.35, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.22)
      ..quadraticBezierTo(w * 0.78, h * 0.10, w * 0.55, h * 0.04)
      ..quadraticBezierTo(w * 0.45, 0, w * 0.35, 0)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            AppColors.primary.withValues(alpha: 0.16),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.25)),
    );

    // Нижняя волна слева.
    final bottom = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.18, h * 0.80, w * 0.42, h * 0.90)
      ..quadraticBezierTo(w * 0.62, h * 0.98, w * 0.7, h)
      ..close();
    canvas.drawPath(
      bottom,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.78, w, h * 0.22)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
