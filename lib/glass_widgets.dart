import 'package:flutter/material.dart';

import 'theme.dart';

/// Мягкое зелёное свечение вокруг карточки объявления.
class GlowCard extends StatelessWidget {
  const GlowCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Переключатель в виде стеклянной капсулы: подсветка плавно переезжает на выбранную вкладку.
class GlassTabs extends StatelessWidget {
  const GlassTabs({required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: AppColors.deep.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: SizedBox(
        height: 42,
        child: Stack(
          children: [
            // Подсветка, которая скользит между вкладками.
            AnimatedAlign(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment(n <= 1 ? 0 : -1 + 2 * selected / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.22),
                        AppColors.primary.withValues(alpha: 0.06),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        blurRadius: 12,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                            color: i == selected ? AppColors.deep : AppColors.ink,
                          ),
                          child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Стеклянное окно по центру: белая карточка со свечением, заголовок и кнопки в одном стиле.
class GlassDialog extends StatelessWidget {
  const GlassDialog({super.key, required this.title, this.content, this.actions = const []});

  final String title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.deep),
              ),
              if (content != null) ...[const SizedBox(height: 14), content!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Белая нижняя шторка со скруглением сверху и зелёным свечением: оборачивает содержимое шторки.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Стеклянная карточка с мягким зелёным свечением (для профиля и подобных блоков).
BoxDecoration glowDecoration({double radius = 20}) => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.22),
          blurRadius: 22,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ],
    );

/// Оформление нижнего окна (фильтры, выбор): белое стекло со скруглением сверху и зелёным свечением.
BoxDecoration glassSheetDecoration() => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.28),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, -6),
        ),
      ],
    );

/// Фон зелёной шапки главной: векторные волны и силуэт памятника (чёткий при любом размере).
class HeaderArt extends StatelessWidget {
  const HeaderArt({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: const CustomPaint(painter: _HeaderArtPainter(), size: Size.infinite),
    );
  }
}

class _HeaderArtPainter extends CustomPainter {
  const _HeaderArtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Светлая волна сверху.
    final wave = Path()
      ..moveTo(0, h * 0.20)
      ..quadraticBezierTo(w * 0.35, h * 0.02, w * 0.7, h * 0.16)
      ..quadraticBezierTo(w * 0.9, h * 0.24, w, h * 0.10)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(wave, Paint()..color = Colors.white.withValues(alpha: 0.06));

    // 3D-модели зданий справа: объёмные коробки с окнами, от дальнего к ближнему.
    _drawBuilding(canvas, x: w * 0.52, base: h * 0.94, width: w * 0.10, height: h * 0.40, depth: w * 0.05, cols: 2);
    _drawBuilding(canvas, x: w * 0.66, base: h * 0.94, width: w * 0.12, height: h * 0.62, depth: w * 0.06, cols: 3);
    _drawBuilding(canvas, x: w * 0.82, base: h * 0.94, width: w * 0.13, height: h * 0.80, depth: w * 0.07, cols: 3);

    // Тёмная волна внизу для читаемости поиска и текста.
    final low = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.5, h * 0.62, w, h * 0.78)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(low, Paint()..color = Colors.black.withValues(alpha: 0.14));
  }

  /// Объёмное здание с затенением: светлый фасад с округлым градиентом, тёмная боковая грань,
  /// светлая крыша, стеклянные окна со скруглением и тень на земле.
  void _drawBuilding(
    Canvas canvas, {
    required double x,
    required double base,
    required double width,
    required double height,
    required double depth,
    required int cols,
  }) {
    final top = base - height;
    final dy = depth * 0.5; // наклон изометрии
    final front = Rect.fromLTRB(x, top, x + width, base);

    // Мягкая тень на земле.
    canvas.drawOval(
      Rect.fromLTRB(x - width * 0.15, base - 5, x + width + depth + width * 0.1, base + 9),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Боковая грань: от светлого верха к тёмному низу.
    final side = Path()
      ..moveTo(x + width, top)
      ..lineTo(x + width + depth, top - dy)
      ..lineTo(x + width + depth, base - dy)
      ..lineTo(x + width, base)
      ..close();
    final sideRect = Rect.fromLTRB(x + width, top - dy, x + width + depth, base);
    canvas.drawPath(
      side,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.black.withValues(alpha: 0.26)],
        ).createShader(sideRect),
    );

    // Крыша: самая светлая грань.
    final roof = Path()
      ..moveTo(x, top)
      ..lineTo(x + depth, top - dy)
      ..lineTo(x + width + depth, top - dy)
      ..lineTo(x + width, top)
      ..close();
    canvas.drawPath(roof, Paint()..color = Colors.white.withValues(alpha: 0.58));

    // Фасад с горизонтальным градиентом: округлость здания.
    canvas.drawRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.42, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.36),
            Colors.white.withValues(alpha: 0.14),
          ],
        ).createShader(front),
    );
    canvas.drawRect(
      front,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.40),
    );

    // Окна: стеклянные, со скруглением и бликом сверху.
    final pad = width * 0.12;
    final winW = (width - pad * (cols + 1)) / cols;
    final rowH = width * 0.20;
    for (var r = 0;; r++) {
      final wy = top + pad + r * rowH;
      final wBottom = wy + rowH * 0.6;
      if (wBottom > base - pad) break;
      for (var c = 0; c < cols; c++) {
        final wx = x + pad + c * (winW + pad);
        final rect = Rect.fromLTWH(wx, wy, winW, rowH * 0.6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(winW * 0.18)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.70), Colors.white.withValues(alpha: 0.18)],
            ).createShader(rect),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

