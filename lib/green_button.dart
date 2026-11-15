import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Основная зелёная кнопка: переливающийся градиент, движущийся блик и волны.
/// Замена FilledButton для зелёных кнопок приложения.
class GreenButton extends StatefulWidget {
  const GreenButton({super.key, required this.onPressed, required this.child, this.height = 46});

  /// Кнопка с иконкой слева от подписи.
  factory GreenButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    double height = 46,
  }) {
    return GreenButton(
      key: key,
      onPressed: onPressed,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 8), label],
      ),
    );
  }

  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  @override
  State<GreenButton> createState() => _GreenButtonState();
}

class _GreenButtonState extends State<GreenButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration.zero,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.5,
        duration: const Duration.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.height, minWidth: 64),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onPressed,
              onHighlightChanged: _setPressed,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final t = _ctrl.value;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment(-1 + 2 * t, -1),
                        end: Alignment(1 + 2 * t, 1),
                        colors: const [AppColors.primary, AppColors.deep, AppColors.primary],
                        stops: const [0, 0.5, 1],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _ButtonWavesPainter(t)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              child: widget.child,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Тонкие волны и блик, которые медленно движутся внутри кнопки.
class _ButtonWavesPainter extends CustomPainter {
  _ButtonWavesPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(0, size.height);
      final amp = size.height * (0.12 + 0.04 * k);
      final base = size.height * (0.35 + 0.22 * k);
      for (double x = 0; x <= size.width; x += 4) {
        final y = base + amp * math.sin(x / size.width * 2 * math.pi * 1.5 + phase + k * 1.3);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = Colors.white.withValues(alpha: 0.06 + 0.02 * k),
      );
    }
    // Блик, проходящий слева направо.
    final sheenX = (t * 2 - 0.5) * size.width;
    canvas.drawRect(
      Rect.fromLTWH(sheenX - size.width * 0.25, 0, size.width * 0.25, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(sheenX - size.width * 0.25, 0, size.width * 0.25, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _ButtonWavesPainter old) => old.t != t;
}
