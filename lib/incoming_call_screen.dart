import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'call_screen.dart';

// Гудок входящего звонка (web/agora.js).
@JS('agoraRingStart')
external void _ringStart();

@JS('agoraRingStop')
external void _ringStop();

/// Экран входящего звонка: гудит, пока его не примут или не отклонят.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.channel, required this.callerName});

  final String channel;
  final String callerName;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with SingleTickerProviderStateMixin {
  bool _done = false;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void initState() {
    super.initState();
    try {
      _ringStart();
    } catch (_) {
      // Если звук не доступен, экран всё равно работает.
    }
  }

  void _stopRing() {
    if (_done) return;
    _done = true;
    try {
      _ringStop();
    } catch (_) {}
  }

  /// Запоминает итог звонка в уведомлении: 'answered' или 'declined'.
  void _setStatus(String status) {
    Supabase.instance.client
        .rpc('set_call_status', params: {'p_channel': widget.channel, 'p_status': status})
        .catchError((_) {});
  }

  void _accept() {
    _stopRing();
    _setStatus('answered');
    // Уже звоним этому человеку (оба позвонили друг другу): просто закрываем экран входящего.
    if (activeCallChannel == widget.channel) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(channel: widget.channel, title: widget.callerName),
      ),
    );
  }

  void _decline() {
    _stopRing();
    _setStatus('declined');
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopRing();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF052A21),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF0E4A3B), Color(0xFF062E24), Color(0xFF031A15)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _GoldArcsPainter())),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF2FB58A).withValues(alpha: 0.45)),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, color: Color(0xFF24D17E), size: 18),
                          SizedBox(width: 8),
                          Text('Защищённый звонок',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Text(widget.callerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                    const SizedBox(height: 8),
                    Text('Гудки...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => CustomPaint(
                          painter: _PulsePainter(_pulse.value),
                          child: Center(
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [Color(0xFF1A7F5E), Color(0xFF0B5A44)],
                                ),
                                border: Border.all(color: const Color(0xFFF5C451).withValues(alpha: 0.75), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF5C451).withValues(alpha: 0.18),
                                    blurRadius: 30,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(38),
                                child: SvgPicture.asset('assets/logo.svg'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('TAJ Bozor',
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 70, height: 1, color: const Color(0xFFF5C451).withValues(alpha: 0.6)),
                        const SizedBox(width: 12),
                        Text('Всегда рядом',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                        const SizedBox(width: 12),
                        Container(width: 70, height: 1, color: const Color(0xFFF5C451).withValues(alpha: 0.6)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundButton(
                          icon: Icons.call_end_rounded,
                          color: const Color(0xFFE0302F),
                          glow: const Color(0xFFE0302F),
                          label: 'Отклонить',
                          onTap: _decline,
                        ),
                        _RoundButton(
                          icon: Icons.call_rounded,
                          color: const Color(0xFF1FA653),
                          glow: const Color(0xFF24D17E),
                          label: 'Ответить',
                          onTap: _accept,
                        ),
                      ],
                    ),
                    const SizedBox(height: 56),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Расходящиеся круги вокруг логотипа.
class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width / 2;
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFF5C451).withValues(alpha: (1 - p) * 0.35);
      canvas.drawCircle(c, base * (0.7 + 0.3 * p), paint);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFF5C451).withValues(alpha: 0.5);
    canvas.drawCircle(c, base * 0.82, ring);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.t != t;
}

/// Тонкие золотые линии в углах, как на макете.
class _GoldArcsPainter extends CustomPainter {
  const _GoldArcsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFF5C451).withValues(alpha: 0.35);
    final top = Path()
      ..moveTo(0, size.height * 0.36)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.12, size.width * 0.8, -10);
    canvas.drawPath(top, gold);
    final bottom = Path()
      ..moveTo(size.width, size.height * 0.84)
      ..quadraticBezierTo(size.width * 0.7, size.height * 0.92, size.width * 0.3, size.height + 10);
    canvas.drawPath(bottom, gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.glow,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color glow;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: glow.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}
