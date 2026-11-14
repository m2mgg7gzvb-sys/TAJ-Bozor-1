import 'package:flutter/material.dart';

import 'theme.dart';

/// Окно действий объявления: большая кнопка TOP с переливом и красная кнопка «Отметить как продано».
Future<void> showListingActions(
  BuildContext context, {
  required String title,
  required VoidCallback onTop,
  required VoidCallback onSold,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            _ShimmerTopButton(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                onTop();
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ruby,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                onSold();
              },
              child: const Text(
                'Отметить как продано',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Золотая кнопка TOP с переливающимся блеском.
class _ShimmerTopButton extends StatefulWidget {
  const _ShimmerTopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ShimmerTopButton> createState() => _ShimmerTopButtonState();
}

class _ShimmerTopButtonState extends State<_ShimmerTopButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

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
        final dx = -1.5 + 3 * _c.value;
        return Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment(dx - 1, 0),
                end: Alignment(dx + 1, 0),
                colors: const [
                  Color(0xFFB8801A),
                  Color(0xFFF5C451),
                  Color(0xFFFFF0B3),
                  Color(0xFFF5C451),
                  Color(0xFFB8801A),
                ],
                stops: const [0, 0.35, 0.5, 0.65, 1],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x55D9A022), blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onPressed,
              child: const SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: AppColors.ink, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Продвинуть в TOP',
                      style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
