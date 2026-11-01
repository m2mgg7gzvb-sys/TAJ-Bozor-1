import 'package:flutter/material.dart';

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
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, size: 96, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'TAJBozor',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
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
