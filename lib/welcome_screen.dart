import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_phone.dart';
import 'auth_screen.dart';
import 'nav_state.dart';
import 'theme.dart';

/// Адрес сайта, куда возвращается вход через Apple и Google.
const _siteUrl = 'https://taj-bozor-1.pages.dev';

/// Экран входа поверх вкладки. Закрывается сам, как только человек вошёл.
class LoginRoute extends StatefulWidget {
  const LoginRoute({super.key, required this.child});

  final Widget child;

  @override
  State<LoginRoute> createState() => _LoginRouteState();
}

class _LoginRouteState extends State<LoginRoute> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.session != null && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Вход для гостя: сначала логотип и название по центру, затем сразу
/// открывается окно «Войти» с кнопками.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onSkip});

  /// Что делать по «Пропустить». Если не задано, открывается вкладка «Поиск».
  final VoidCallback? onSkip;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _c.forward();
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

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoginRoute(child: page)));
  }

  void _openEmail() {
    _push(
      Scaffold(
        appBar: AppBar(),
        body: const SafeArea(child: AuthScreen()),
      ),
    );
  }

  void _openPhone() => _push(const PhoneAuthScreen());

  void _skip() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      tabIndex.value = 0;
    }
  }

  Future<void> _oauth(OAuthProvider provider) async {
    try {
      // prompt=select_account: Google каждый раз спрашивает, каким аккаунтом войти.
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: _siteUrl,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вход через этот сервис пока не подключён')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.4, end: 1).animate(_part(0, 0.45, Curves.elasticOut)),
                      child: FadeTransition(
                        opacity: _part(0, 0.2),
                        child: SvgPicture.asset('assets/logo.svg', width: 110, height: 110),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _part(0.35, 0.7),
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
                  ],
                ),
              ),
            ),
            SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(_part(0.75, 1, Curves.easeOutCubic)),
              child: _Sheet(
                onApple: () => _oauth(OAuthProvider.apple),
                onGoogle: () => _oauth(OAuthProvider.google),
                onPhone: _openPhone,
                onEmail: _openEmail,
                onSkip: _skip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.onApple,
    required this.onGoogle,
    required this.onPhone,
    required this.onEmail,
    required this.onSkip,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onPhone;
  final VoidCallback onEmail;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Войти',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            onPressed: onApple,
            child: const Text('Продолжить с Apple'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: Color(0xFFD5DAD8)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onGoogle,
            child: const Text('Продолжить с Google'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onPhone,
            child: const Text('Войти по номеру'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF1F4F3),
              foregroundColor: AppColors.ink,
            ),
            onPressed: onEmail,
            child: const Text('Войти по почте'),
          ),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Пропустить',
              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ),
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
