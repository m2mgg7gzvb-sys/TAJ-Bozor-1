import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'call_widgets.dart';
import 'green_button.dart';
import 'lang_store.dart';

/// Что случилось при запуске: нет интернета или другая ошибка.
enum ConnectionProblem { offline, error }

/// Экран без интернета или ошибки при запуске, с кнопкой «Повторить».
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, required this.problem, required this.onRetry});

  final ConnectionProblem problem;
  final VoidCallback onRetry;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.problem == ConnectionProblem.offline;
    final title = offline
        ? tr('Нет подключения к интернету', 'Пайвасти интернет нест')
        : tr('Ошибка', 'Хато');
    final subtitle = offline
        ? tr('Проверьте ваше соединение и попробуйте снова', 'Пайвастро санҷед ва бори дигар кӯшиш кунед')
        : tr('Что-то пошло не так. Попробуйте еще раз позже.',
            'Чизе нодуруст шуд. Баъдтар бори дигар кӯшиш кунед.');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CallBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox(
                  width: 240,
                  height: 240,
                  child: AnimatedBuilder(
                    animation: _orbit,
                    builder: (context, _) {
                      final t = _orbit.value * 2 * math.pi;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Два золотых эллипса, которые качаются вокруг значка.
                          Transform.rotate(
                            angle: 0.45 * math.sin(t),
                            child: _Orbit(color: kCallGold.withValues(alpha: 0.7)),
                          ),
                          Transform.rotate(
                            angle: -0.5 + 0.35 * math.cos(t),
                            child: _Orbit(color: kCallGold.withValues(alpha: 0.35)),
                          ),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [Color(0xFF1A7F5E), Color(0xFF0B5A44)]),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: kCallGold.withValues(alpha: 0.15 + 0.15 * math.sin(t).abs()),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Center(child: _icon(offline)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.2)),
                const SizedBox(height: 10),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, height: 1.4)),
                const Spacer(),
                SizedBox(
                  width: 260,
                  child: GreenButton.icon(
                    onPressed: widget.onRetry,
                    height: 54,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(tr('Повторить', 'Такрор')),
                  ),
                ),
                const Spacer(),
                const _BrandFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon(bool offline) {
    if (!offline) {
      return const Icon(Icons.warning_amber_rounded, color: kCallGold, size: 80);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.wifi_rounded, color: Colors.white, size: 70),
        Positioned(
          right: -8,
          bottom: -4,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kCallGold),
            child: const Text('!',
                style: TextStyle(color: Color(0xFF0B3B2E), fontSize: 20, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _Orbit extends StatelessWidget {
  const _Orbit({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

/// Внизу: золотые линии и название TAJ Bozor, как на экране входа.
class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    Widget line() => Container(width: 80, height: 1, color: kCallGold.withValues(alpha: 0.6));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line(),
        const SizedBox(width: 14),
        const Text('TAJ Bozor',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
        const SizedBox(width: 14),
        line(),
      ],
    );
  }
}
