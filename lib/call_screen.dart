import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';

// Мост к web/agora.js (Agora Web SDK).
@JS('agoraJoin')
external JSPromise<JSBoolean> _jsJoin(JSString appId, JSString channel, JSString token, JSNumber uid);

@JS('agoraSetMic')
external JSPromise<JSBoolean> _jsSetMic(JSBoolean on);

@JS('agoraLeave')
external JSPromise<JSBoolean> _jsLeave();

/// Канал одинаков для двух собеседников: собирается из их id (отсортированных),
/// поэтому оба попадают в одну комнату, если открыли звонок.
String pairChannel(String a, String b) {
  String short(String id) => id.replaceAll('-', '').substring(0, 16);
  final parts = [short(a), short(b)]..sort();
  return 'tb_${parts.join('_')}';
}

/// Экран голосового звонка через Интернет.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.channel, required this.title});

  final String channel;
  final String title;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String _status = 'Подключение…';
  bool _joined = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('agora-token', body: {'channel': widget.channel});
      final data = Map<String, dynamic>.from(res.data as Map);
      await _jsJoin(
        (data['appId'] as String).toJS,
        widget.channel.toJS,
        (data['token'] as String).toJS,
        (data['uid'] as num).toDouble().toJS,
      ).toDart;
      if (!mounted) return;
      setState(() {
        _joined = true;
        _status = tr('Вы в разговоре', 'Шумо дар сӯҳбат');
      });
    } catch (e) {
      if (!mounted) return;
      final reason = e.toString();
      setState(() => _status = '${tr('Не удалось подключиться', 'Пайваст нашуд')}\n${reason.length > 160 ? reason.substring(0, 160) : reason}');
    }
  }

  Future<void> _toggleMic() async {
    if (!_joined) return;
    final next = !_muted;
    await _jsSetMic(next.toJS).toDart;
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _hangUp() async {
    if (_joined) {
      try {
        await _jsLeave().toDart;
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (_joined) {
      _jsLeave().toDart.ignore();
    }
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
              const SizedBox(height: 40),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: Colors.white24,
                    label: _muted ? tr('Включить', 'Фаъол') : tr('Выключить', 'Хомӯш'),
                    onTap: _toggleMic,
                  ),
                  _CircleButton(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE53935),
                    label: tr('Завершить', 'Қатъ'),
                    onTap: _hangUp,
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.color, required this.label, required this.onTap});

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
