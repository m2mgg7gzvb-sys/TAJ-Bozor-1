import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'theme.dart';

/// Экран входа для гостя по образцу макета: после анимации логотипа появляются
/// название по центру и белая панель с кнопками. Фон и цвета — наши.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // Когда человек вошёл, закрываем все экраны входа поверх вкладки.
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _c.dispose();
    super.dispose();
  }

  Animation<double> _part(double begin, double end, [Curve curve = Curves.easeOut]) {
    return CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));
  }

  void _openAuth() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: const SafeArea(child: AuthScreen()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Для тех, кто отключил анимации в системе, сразу показываем готовый экран.
    if (MediaQuery.of(context).disableAnimations && _c.value < 1) {
      _c.value = 1;
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.deep],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 28),
            ScaleTransition(
              scale: Tween<double>(begin: 0.4, end: 1).animate(_part(0, 0.5, Curves.elasticOut)),
              child: FadeTransition(
                opacity: _part(0, 0.2),
                child: SvgPicture.asset('assets/logo.svg', width: 88, height: 88),
              ),
            ),
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _part(0.4, 0.75),
                  child: const Text(
                    'TAJ Bozor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(_part(0.6, 1, Curves.easeOutCubic)),
              child: FadeTransition(
                opacity: _part(0.6, 0.9),
                child: _Sheet(onTap: _openAuth),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Бозор дар ҷайби шумо',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onTap,
            child: const Text('Войти по почте'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF1F4F3),
              foregroundColor: AppColors.ink,
            ),
            onPressed: onTap,
            child: const Text('Создать аккаунт'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Продолжая, вы принимаете условия использования\nи политику конфиденциальности TAJ Bozor',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
