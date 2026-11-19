import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'theme.dart';

/// Подгонка фото профиля: фото двигается и масштабируется внутри круга.
/// Возвращает PNG только того, что видно в круге, или null, если пользователь вышел.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _done() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!mounted) return;
      Navigator.of(context).pop(data?.buffer.asUint8List());
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.sizeOf(context).width - 64;
    return Scaffold(
      // Фон экрана — как у приложения: вокруг круга ничего лишнего, фото видно на фоне темы
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.title,
        title: Text(
          'Фото профиля',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.title),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _done,
            child: Text(
              'Готово',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Квадрат с шашечкой: там, где фото не закрывает квадрат, видно прозрачный фон
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: const _CheckerPainter(),
                  ),
                ),
                RepaintBoundary(
                  key: _boundaryKey,
                  child: ClipOval(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(
                          widget.bytes,
                          width: side,
                          height: side,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Сдвигайте и увеличивайте фото, чтобы выбрать, как оно будет смотреться',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Шашечка для показа прозрачного фона.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final light = Paint()..color = const Color(0xFFFFFFFF);
    final dark = Paint()..color = const Color(0xFFD9D9D9);
    canvas.drawRect(Offset.zero & size, light);
    final cols = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isOdd) {
          canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
