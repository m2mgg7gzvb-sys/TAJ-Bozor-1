import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'theme.dart';

/// Подгонка фото профиля: круг — это то, что останется в профиле, а края фото видны за ним.
/// Возвращает PNG только того, что внутри круга (вне круга прозрачно), или null, если вышли.
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
      final shot = await boundary.toImage(pixelRatio: 2.0);
      final size = shot.width.toDouble();

      // Обрезаем по кругу: всё вне круга становится прозрачным
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size, size)));
      canvas.drawImage(shot, Offset.zero, Paint());
      final picture = recorder.endRecording();
      final round = await picture.toImage(shot.width, shot.height);
      final data = await round.toByteData(format: ui.ImageByteFormat.png);

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
                // Всё фото целиком (с краями), подгоняется пальцами
                RepaintBoundary(
                  key: _boundaryKey,
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
                // Затемнение за кругом и рамка круга (не попадают в сохранённое фото)
                IgnorePointer(
                  child: CustomPaint(
                    size: Size(side, side),
                    painter: _CircleFramePainter(),
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

/// Затемняет всё, кроме круга, и рисует рамку круга.
class _CircleFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect);
    final outside = Path()
      ..addRect(rect)
      ..addPath(circle, Offset.zero);
    outside.fillType = PathFillType.evenOdd;
    canvas.drawPath(outside, Paint()..color = const Color(0x66000000));
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF0E7C66),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
