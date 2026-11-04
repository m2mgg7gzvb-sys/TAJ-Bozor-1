import 'package:flutter/material.dart';

import 'theme.dart';

const _base = Color(0xFFEAEEEC);

/// Мерцание серых блоков, пока грузятся объявления (1,2 с). Если в системе
/// включено «уменьшить движение», блоки просто стоят.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final s = -0.3 + 1.6 * _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            colors: const [_base, Color(0xFFF8FAF9), _base],
            stops: [
              (s - 0.3).clamp(0.0, 1.0),
              s.clamp(0.0, 1.0),
              (s + 0.3).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Серый прямоугольник-заглушка.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Сетка из двух колонок с заглушками карточек (для главной).
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.66,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: cardDecoration(radius: 11),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SizedBox.expand(child: ColoredBox(color: _base))),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14),
                        SizedBox(height: 8),
                        SkeletonBox(width: 90, height: 16),
                        SizedBox(height: 8),
                        SkeletonBox(width: 60, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Список из крупных заглушек карточек (для результатов поиска).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: cardDecoration(radius: 14),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 190, width: double.infinity, child: ColoredBox(color: _base)),
                    Padding(
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 140, height: 20),
                          SizedBox(height: 10),
                          SkeletonBox(height: 14),
                          SizedBox(height: 8),
                          SkeletonBox(width: 200, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
