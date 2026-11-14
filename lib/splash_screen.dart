import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'root_gate.dart';

/// Вход в приложение: фон с фото памятника и движущимися волнами, логотип в светлой рамке,
/// название и слоган появляются, точки внизу пульсируют. Затем экран растворяется.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _exit;
  // Непрерывный цикл: волны, наезд на фото, пульс свечения логотипа и точки.
  late final AnimationController _loop;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _logoScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.45, 0.9, curve: Curves.easeOut));
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.45, 0.95, curve: Curves.easeOutCubic)),
    );

    Future.delayed(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      await _exit.forward();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const RootGate(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF063A30),
      body: AnimatedBuilder(
        animation: Listenable.merge([_exit]),
        builder: (context, child) {
          return Opacity(
            opacity: 1 - _exit.value,
            child: Transform.scale(scale: 1 + _exit.value * 0.05, child: child),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B6A57), Color(0xFF063A30)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Фото памятника справа вверху: медленно наезжает и гаснет к краям.
            AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => Align(
                alignment: Alignment.topRight,
                child: FractionallySizedBox(
                  widthFactor: 0.9,
                  heightFactor: 0.55,
                  child: Transform.scale(
                    scale: 1.0 + 0.06 * _loop.value,
                    alignment: Alignment.topRight,
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Colors.transparent, Colors.white],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: Opacity(
                        opacity: 0.5,
                        child: Image.asset('assets/welcome_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topRight),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Волны, которые плавно плывут.
            AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => CustomPaint(painter: _WavesPainter(_loop.value)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _loop,
                        builder: (context, child) {
                          final pulse = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi);
                          return Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(44),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7CF0C2).withValues(alpha: 0.12 + 0.12 * pulse),
                                  blurRadius: 30 + 10 * pulse,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: SvgPicture.asset('assets/logo.svg', width: 104, height: 104),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Text.rich(
                        const TextSpan(
                          style: TextStyle(color: Colors.white, fontSize: 34, height: 1, letterSpacing: -0.5),
                          children: [
                            TextSpan(text: 'TAJ ', style: TextStyle(fontWeight: FontWeight.w800)),
                            TextSpan(text: 'Bozor', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _textFade,
                    child: const Text(
                      'Бозор дар ҷайби шумо',
                      style: TextStyle(color: Color(0xFFD5EDE5), fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(opacity: _textFade, child: _BouncingDots(animation: _loop)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Волны: три полупрозрачных слоя, каждый плывёт с своей фазой.
class _WavesPainter extends CustomPainter {
  _WavesPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    for (var i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final dx = math.sin(phase * 2 * math.pi) * w * 0.08;
      final top = h * (0.58 + i * 0.12);
      final path = Path()
        ..moveTo(-w * 0.2 + dx, top)
        ..quadraticBezierTo(w * 0.3 + dx, top - h * 0.10, w * 0.6 + dx, top + h * 0.02)
        ..quadraticBezierTo(w * 0.9 + dx, top + h * 0.10, w * 1.3 + dx, top - h * 0.04)
        ..lineTo(w * 1.3 + dx, h)
        ..lineTo(-w * 0.2 + dx, h)
        ..close();
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.035 + 0.02 * i));
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) => oldDelegate.t != t;
}

/// Три золотые точки: каждая поднимается и гаснет со сдвигом по фазе.
class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final wave = math.sin((animation.value * 2 * math.pi * 2) - i * 0.9);
            final up = wave.clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, -12 * up),
              child: Opacity(
                opacity: 0.45 + 0.55 * up,
                child: Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: const BoxDecoration(color: Color(0xFFF5B301), shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
