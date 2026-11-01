import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'root_gate.dart';
import 'theme.dart';

/// Загрузочный экран из макета: логотип появляется с пружиной, название плавно проявляется, точки прыгают.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _logo;
  late final Animation<double> _text;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
      ..forward();
    _logo = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _text = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _logo,
              child: SvgPicture.asset('assets/logo.svg', width: 120, height: 120),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _text,
              child: Text.rich(
                const TextSpan(
                  style: TextStyle(color: Colors.white, fontSize: 32, height: 1),
                  children: [
                    TextSpan(text: 'TAJ ', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: 'Bozor', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _text,
              child: const Text(
                'Бозор дар ҷайби шумо',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 32),
            const _BouncingDots(),
          ],
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
