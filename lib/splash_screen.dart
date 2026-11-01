import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'root_gate.dart';
import 'theme.dart';

/// Экран загрузки: зелёный фон, логотип и слоган из макета.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('assets/logo.svg', width: 120, height: 120),
            SizedBox(height: 20),
            Text.rich(
              TextSpan(
                style: TextStyle(color: Colors.white, fontSize: 32, height: 1),
                children: [
                  TextSpan(text: 'TAJ ', style: TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: 'Bozor', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Бозор дар ҷайби шумо',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
