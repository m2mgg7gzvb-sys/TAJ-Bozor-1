import 'dart:js_interop';

import 'package:flutter/material.dart';
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

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  bool _done = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2421),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text('Входящий звонок',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 12),
              Text(widget.callerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundButton(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE53935),
                    label: 'Отклонить',
                    onTap: _decline,
                  ),
                  _RoundButton(
                    icon: Icons.call_rounded,
                    color: const Color(0xFF13C15A),
                    label: 'Ответить',
                    onTap: _accept,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.color, required this.label, required this.onTap});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 72, height: 72, child: Icon(icon, color: Colors.white, size: 32)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}
