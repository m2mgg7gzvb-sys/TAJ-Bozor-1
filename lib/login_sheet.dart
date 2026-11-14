import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'theme.dart';
import 'glass_widgets.dart';

const _defaultReason = 'Вход нужен, чтобы писать продавцам и сохранять избранное';

/// Если пользователь не вошёл — показывает шторку входа и возвращает false.
/// Если вошёл — сразу true, и действие можно продолжать.
Future<bool> requireLogin(BuildContext context, {String reason = _defaultReason}) async {
  if (Supabase.instance.client.auth.currentUser != null) return true;
  await showLoginSheet(context, reason: reason);
  return false;
}

/// Шторка «Войдите в TAJBozor»: выезжает снизу за 0,3 с, фон затемняется,
/// закрывается тапом по фону.
Future<void> showLoginSheet(BuildContext context, {String reason = _defaultReason}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, animation, _) => _LoginOverlay(reason: reason, animation: animation),
    transitionBuilder: (ctx, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _LoginOverlay extends StatelessWidget {
  const _LoginOverlay({required this.reason, required this.animation});

  final String reason;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/logo.svg', width: 110, height: 110),
                  const SizedBox(height: 18),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Войдите в TAJBozor',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Покупайте и продавайте рядом с домом',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: const _Sheet(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  void _go(BuildContext context, {required bool register}) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => AuthRoute(startRegister: register)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: glassSheetDecoration(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DAD8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                onPressed: () => _go(context, register: false),
                child: const Text('Войти по почте'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F4F3),
                  foregroundColor: AppColors.ink,
                ),
                onPressed: () => _go(context, register: true),
                child: const Text('Зарегистрироваться по почте'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Вход по номеру появится позже')),
                ),
                child: const Text(
                  'Войти по номеру +992',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Продолжая, вы принимаете условия использования\nTAJBozor и политику конфиденциальности',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Экран входа/регистрации как отдельная страница. Закрывается сам после входа.
class AuthRoute extends StatefulWidget {
  const AuthRoute({super.key, required this.startRegister});

  final bool startRegister;

  @override
  State<AuthRoute> createState() => _AuthRouteState();
}

class _AuthRouteState extends State<AuthRoute> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(child: AuthScreen(startRegister: widget.startRegister)),
    );
  }
}
