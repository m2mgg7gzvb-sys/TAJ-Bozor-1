import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'call_screen.dart';
import 'call_widgets.dart';
import 'notify_store.dart';

// Мелодия и вибрация входящего звонка (web/agora.js).
@JS('agoraRingStart')
external void _ringStart();

@JS('agoraRingStop')
external void _ringStop();

OverlayEntry? _banner;

/// Входящий звонок сверху экрана. Не пропадает, пока человек не ответит или не отклонит.
void showIncomingCallBanner({required String channel, required String callerName}) {
  if (_banner != null) return; // уже звонит
  final overlay = appNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  void close() {
    if (entry.mounted) entry.remove();
    if (identical(_banner, entry)) _banner = null;
  }

  entry = OverlayEntry(
    builder: (_) => _IncomingCallBanner(channel: channel, callerName: callerName, close: close),
  );
  _banner = entry;
  overlay.insert(entry);
}

class _IncomingCallBanner extends StatefulWidget {
  const _IncomingCallBanner({required this.channel, required this.callerName, required this.close});

  final String channel;
  final String callerName;
  final VoidCallback close;

  @override
  State<_IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<_IncomingCallBanner> with SingleTickerProviderStateMixin {
  bool _done = false;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void initState() {
    super.initState();
    try {
      _ringStart();
    } catch (_) {
      // Если звук не доступен, баннер всё равно работает.
    }
    // Сообщаем звонящему, что приглашение дошло и звонит у нас.
    _setStatus('ringing');
  }

  @override
  void dispose() {
    _stopRing();
    _pulse.dispose();
    super.dispose();
  }

  void _stopRing() {
    if (_done) return;
    _done = true;
    try {
      _ringStop();
    } catch (_) {}
  }

  /// Запоминает статус звонка в уведомлении: 'ringing', 'answered' или 'declined'.
  void _setStatus(String status) {
    Supabase.instance.client
        .rpc('set_call_status', params: {'p_channel': widget.channel, 'p_status': status})
        .catchError((_) {});
  }

  void _accept() {
    _stopRing();
    _setStatus('answered');
    widget.close();
    // Уже звоним этому человеку (оба позвонили друг другу): просто закрываем баннер.
    if (activeCallChannel == widget.channel) return;
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(channel: widget.channel, title: widget.callerName),
      ),
    );
  }

  void _decline() {
    _stopRing();
    _setStatus('declined');
    widget.close();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0E4A3B), Color(0xFF062E24)],
                ),
                border: Border.all(color: kCallGold.withValues(alpha: 0.5)),
                boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black38)],
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final glow = 0.5 - 0.5 * math.cos(2 * math.pi * _pulse.value);
                      return Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0B5A44),
                          border: Border.all(color: kCallGold.withValues(alpha: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: kCallGold.withValues(alpha: 0.2 + 0.4 * glow),
                              blurRadius: 10 + 12 * glow,
                              spreadRadius: 1 + 3 * glow,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png'),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Входящий звонок',
                            style: TextStyle(color: kCallGold, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'от ${widget.callerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  _BannerButton(icon: Icons.call_end_rounded, color: const Color(0xFFE0302F), onTap: _decline),
                  const SizedBox(width: 10),
                  _BannerButton(icon: Icons.call_rounded, color: const Color(0xFF1FA653), onTap: _accept),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
