import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_phone.dart';
import 'auth_intent.dart';
import 'auth_screen.dart';
import 'glass_widgets.dart';
import 'nav_state.dart';
import 'theme.dart';

/// Адрес сайта, куда возвращается вход через Apple и Google.
const _siteUrl = 'https://app.tajbozor.pro';

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
        // Даём показать галочку «подтверждено», потом закрываем экран входа.
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        });
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

  void _openEmail(bool register) {
    _push(
      Scaffold(
        appBar: AppBar(),
        body: SafeArea(child: AuthScreen(startRegister: register)),
      ),
    );
  }

  void _openPhone(bool register) => _push(PhoneAuthScreen(register: register));

  void _skip() {
    if (widget.onSkip != null) {
      widget.onSkip!();
    } else {
      tabIndex.value = 0;
    }
  }

  Future<void> _oauth(OAuthProvider provider, bool register) async {
    await rememberAuthIntent(register: register);
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
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DarkWavesPainter())),
          SafeArea(
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
                onApple: (r) => _oauth(OAuthProvider.apple, r),
                onGoogle: (r) => _oauth(OAuthProvider.google, r),
                onPhone: _openPhone,
                onEmail: _openEmail,
                onSkip: _skip,
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.onApple,
    required this.onGoogle,
    required this.onPhone,
    required this.onEmail,
    required this.onSkip,
  });

  final ValueChanged<bool> onApple;
  final ValueChanged<bool> onGoogle;
  final ValueChanged<bool> onPhone;
  final ValueChanged<bool> onEmail;
  final VoidCallback onSkip;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _register = false; // false — вход, true — регистрация

  @override
  Widget build(BuildContext context) {
    final onApple = widget.onApple;
    final onGoogle = widget.onGoogle;
    final onPhone = widget.onPhone;
    final onEmail = widget.onEmail;
    final onSkip = widget.onSkip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deep.withValues(alpha: 0.35),
            blurRadius: 36,
            spreadRadius: -6,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTabs(
            labels: const ['Вход', 'Регистрация'],
            selected: _register ? 1 : 0,
            onChanged: (i) => setState(() => _register = i == 1),
          ),
          const SizedBox(height: 18),
          Text(
            _register ? 'Создать аккаунт' : 'Войти',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            _register
                ? 'Аккаунт создастся автоматически при первом входе'
                : 'Войдите, чтобы публиковать объявления и писать продавцам',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          // Тонкая зелёная линия-разделитель, как в макете.
          Container(
            height: 2,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.primary, Colors.transparent],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _PillButton(
            label: _register ? 'Зарегистрироваться через Apple' : 'Продолжить с Apple',
            filled: true,
            onPressed: () => onApple(_register),
          ),
          const SizedBox(height: 12),
          _PillButton(
            label: _register ? 'Зарегистрироваться через Google' : 'Продолжить с Google',
            filled: false,
            onPressed: () => onGoogle(_register),
          ),
          if (!_register) ...[
            const SizedBox(height: 12),
            _PillButton(label: 'Войти по номеру', filled: true, onPressed: () => onPhone(false)),
          ],
          const SizedBox(height: 12),
          _PillButton(
            label: _register ? 'Зарегистрироваться по почте' : 'Войти по почте',
            filled: false,
            onPressed: () => onEmail(_register),
          ),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Пропустить',
              style: TextStyle(color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.w700),
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

/// Кнопка-капсула: зелёная заливка с мягким свечением или белое стекло с обводкой.
class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.filled, required this.onPressed});

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: filled ? 0.45 : 0.18),
            blurRadius: filled ? 20 : 14,
            spreadRadius: -3,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: filled
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.deep],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [Colors.white, Color(0xFFEEF4F2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            border: filled ? null : Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : AppColors.deep,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Мягкие волны на зелёном фоне входа.
class _DarkWavesPainter extends CustomPainter {
  const _DarkWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = Path()
      ..moveTo(0, h * 0.12)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w, h * 0.14)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(top, Paint()..color = Colors.white.withValues(alpha: 0.05));
    final low = Path()
      ..moveTo(0, h * 0.52)
      ..quadraticBezierTo(w * 0.45, h * 0.40, w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(low, Paint()..color = Colors.black.withValues(alpha: 0.10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
