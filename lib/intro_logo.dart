import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Звёзды логотипа: центр (x, y) и размер (w, h) в долях от размера логотипа.
/// Порядок совпадает с файлами assets/logo_stars/star_0..6.png.
const _stars = <(double, double, double, double)>[
  (0.5012, 0.2460, 0.1029, 0.0981),
  (0.3660, 0.2775, 0.0957, 0.0893),
  (0.6352, 0.2779, 0.0949, 0.0885),
  (0.7588, 0.3437, 0.0949, 0.0909),
  (0.2424, 0.3465, 0.0957, 0.0869),
  (0.8469, 0.4322, 0.0909, 0.0893),
  (0.1535, 0.4338, 0.0917, 0.0861),
];

/// Логотип, в который звёзды прилетают с разных сторон и встают на свои места.
class IntroLogo extends StatefulWidget {
  const IntroLogo({super.key, required this.size});

  final double size;

  @override
  State<IntroLogo> createState() => _IntroLogoState();
}

class _IntroLogoState extends State<IntroLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _star(int i, double t, double size) {
    final (cx, cy, w, h) = _stars[i];
    // Каждая звезда начинает лететь чуть позже предыдущей.
    final start = 0.12 + i * 0.07;
    final p = ((t - start) / 0.5).clamp(0.0, 1.0);
    // easeOutBack: звезда немного проскакивает место и встаёт на него.
    final e = Curves.easeOutBack.transform(p);
    final dx = cx - 0.5;
    final dy = cy - 0.5;
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len;
    final uy = dy / len;
    final side = i.isEven ? 1.0 : -1.0;
    // Старт — далеко от логотипа, немного сбоку, чтобы путь был дугой.
    final fromX = cx + ux * 0.7 - uy * 0.25 * side;
    final fromY = cy + uy * 0.7 + ux * 0.25 * side;
    final x = fromX + (cx - fromX) * e;
    final y = fromY + (cy - fromY) * e;
    final angle = (1 - e) * -side * 2.4;
    final opacity = (p * 4).clamp(0.0, 1.0);
    return Positioned(
      left: (x - w / 2) * size,
      top: (y - h / 2) * size,
      width: w * size,
      height: h * size,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Image.asset('assets/logo_stars/star_$i.png', fit: BoxFit.fill),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final baseP = Curves.easeOut.transform((t / 0.35).clamp(0.0, 1.0));
          return Stack(
            children: [
              Opacity(
                opacity: baseP,
                child: Transform.scale(
                  scale: 0.92 + 0.08 * baseP,
                  child: Image.asset('assets/logo_base.png', width: size, height: size),
                ),
              ),
              for (var i = 0; i < _stars.length; i++) _star(i, t, size),
            ],
          );
        },
      ),
    );
  }
}
