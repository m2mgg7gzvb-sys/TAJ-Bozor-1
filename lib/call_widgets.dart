import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Золотой цвет линий и рамок звонка (как на макете).
const kCallGold = Color(0xFFF5C451);

/// Тёмно-зелёный фон экрана звонка: медленно дышащее свечение и плывущие золотые линии.
class CallBackground extends StatefulWidget {
  const CallBackground({super.key, required this.child});

  final Widget child;

  @override
  State<CallBackground> createState() => _CallBackgroundState();
}

class _CallBackgroundState extends State<CallBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        // Центр свечения плавно качается по кругу.
        final center = Alignment(0.25 * math.cos(t), -0.35 + 0.15 * math.sin(t));
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: 1.1,
              colors: const [Color(0xFF0E4A3B), Color(0xFF062E24), Color(0xFF031A15)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: GoldArcsPainter(t)),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Тонкие золотые линии в углах; их изгибы плавно плывут.
class GoldArcsPainter extends CustomPainter {
  const GoldArcsPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = kCallGold.withValues(alpha: 0.35);
    final wobble = 0.04 * math.sin(t);
    final top = Path()
      ..moveTo(0, size.height * (0.36 + wobble))
      ..quadraticBezierTo(size.width * 0.35, size.height * (0.12 - wobble), size.width * 0.8, -10);
    canvas.drawPath(top, gold);
    final bottom = Path()
      ..moveTo(size.width, size.height * (0.84 - wobble))
      ..quadraticBezierTo(size.width * 0.7, size.height * (0.92 + wobble), size.width * 0.3, size.height + 10);
    canvas.drawPath(bottom, gold);
  }

  @override
  bool shouldRepaint(covariant GoldArcsPainter old) => old.t != t;
}

/// Круги, которые расходятся от кнопки (анимированное свечение).
class PulseRings extends StatefulWidget {
  const PulseRings({super.key, required this.color, required this.child, this.size = 84});

  /// Диаметр самой кнопки внутри.
  final double size;
  final Color color;
  final Widget child;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.size * 2.2;
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size.square(box),
              painter: _RingsPainter(_c.value, widget.color),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.width / 2;
    final baseR = maxR * 0.45;
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: (1 - p) * 0.45);
      canvas.drawCircle(c, baseR + (maxR - baseR) * p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t != t || old.color != color;
}

/// Золотые линии, которые танцуют в такт голосу: высота зависит от громкости.
class VoiceBars extends StatefulWidget {
  const VoiceBars({super.key, required this.level});

  /// Громкость от 0 до 1.
  final ValueListenable<double> level;

  @override
  State<VoiceBars> createState() => _VoiceBarsState();
}

class _VoiceBarsState extends State<VoiceBars> with SingleTickerProviderStateMixin {
  static const _shape = [0.45, 0.8, 1.0, 0.8, 0.45];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => ValueListenableBuilder<double>(
          valueListenable: widget.level,
          builder: (context, lvl, _) {
            final t = _c.value * 2 * math.pi;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _shape.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Container(
                      width: 6,
                      height: 6 + 46 * _shape[i] * lvl * (0.45 + 0.55 * (0.5 + 0.5 * math.sin(t + i * 1.1))),
                      decoration: BoxDecoration(color: kCallGold, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
