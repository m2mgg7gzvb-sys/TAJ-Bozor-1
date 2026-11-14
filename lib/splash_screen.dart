import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'root_gate.dart';
import 'theme.dart';

/// Вход в приложение: логотип плавно появляется, название поднимается снизу,
/// фон мягко переходит в тёмно-зелёный, затем экран растворяется.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _exit;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _bgShift;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _logoScale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(parent: _intro, curve: const Interval(0.0, 0.4, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _intro, curve: const Interval(0.45, 0.9, curve: Curves.easeOut));
    _textSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.45, 0.95, curve: Curves.easeOutCubic)),
    );
    _bgShift = CurvedAnimation(parent: _intro, curve: Curves.easeInOut);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _exit, _bgShift]),
        builder: (context, child) {
          final bg = Color.lerp(AppColors.primary, AppColors.deep, _bgShift.value * 0.6)!;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, bg],
              ),
            ),
            child: Opacity(
              opacity: 1 - _exit.value,
              child: Transform.scale(scale: 1 + _exit.value * 0.05, child: child),
            ),
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: SvgPicture.asset('assets/logo.svg', width: 104, height: 104),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: Text.rich(
                    const TextSpan(
                      style: TextStyle(color: Colors.white, fontSize: 32, height: 1, letterSpacing: -0.5),
                      children: [
                        TextSpan(text: 'TAJ ', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: 'Bozor', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'Бозор дар ҷайби шумо',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              const SizedBox(height: 36),
              FadeTransition(opacity: _textFade, child: const _BouncingDots()),
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loop,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final dy = math.sin((_loop.value * 2 * math.pi) - i * 0.8).clamp(0.0, 1.0) * -8;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5B301),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
