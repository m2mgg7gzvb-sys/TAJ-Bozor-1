import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'call_widgets.dart';
import 'lang_store.dart';

// Мост к web/agora.js (Agora Web SDK).
@JS('agoraJoin')
external JSPromise<JSBoolean> _jsJoin(JSString appId, JSString channel, JSString token, JSNumber uid);

@JS('agoraSetMic')
external JSPromise<JSBoolean> _jsSetMic(JSBoolean on);

@JS('agoraLeave')
external JSPromise<JSBoolean> _jsLeave();

@JS('agoraIsConnected')
external JSBoolean _jsIsConnected();

@JS('agoraLevel')
external JSNumber _jsLevel();

/// Канал одинаков для двух собеседников: собирается из их id (отсортированных),
/// поэтому оба попадают в одну комнату, если открыли звонок.
String pairChannel(String a, String b) {
  String short(String id) => id.replaceAll('-', '').substring(0, 16);
  final parts = [short(a), short(b)]..sort();
  return 'tb_${parts.join('_')}';
}

/// Отправляет собеседнику входящий звонок (push и экран у него в приложении).
/// Возвращает false, если приглашение не дошло до сервера.
Future<bool> inviteToCall({required String calleeId, required String channel}) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('call-invite', body: {'callee_id': calleeId, 'channel': channel});
    return res.status == 200;
  } catch (_) {
    // Звонящий сам попадает в канал, но собеседник о звонке не узнает.
    return false;
  }
}

String _formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Канал звонка, в котором мы сейчас находимся (чтобы не входить в него дважды).
String? activeCallChannel;

/// Экран голосового звонка через Интернет.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.channel, required this.title});

  final String channel;
  final String title;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _joined = false;
  bool _muted = false;
  String? _error;
  // Статус собеседника: 'ringing' — приглашение у него, 'answered', 'declined' или пусто.
  String _peer = '';
  bool _polling = false;
  Timer? _ticker;
  Timer? _levelTimer;
  final _level = ValueNotifier<double>(0);
  double _smoothLevel = 0;
  DateTime? _connectedAt; // момент, когда собеседник ответил
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    activeCallChannel = widget.channel;
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
      setState(() => _joined = true);
      _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
      _levelTimer = Timer.periodic(const Duration(milliseconds: 120), _sampleLevel);
    } catch (e) {
      if (!mounted) return;
      final reason = e.toString();
      setState(() => _error =
          '${tr('Не удалось подключиться', 'Пайваст нашуд')}\n${reason.length > 160 ? reason.substring(0, 160) : reason}');
    }
  }

  /// Громкость для анимации золотых линий (часто, без перерисовки всего экрана).
  void _sampleLevel(Timer _) {
    if (!mounted || !_joined) return;
    double raw = 0;
    try {
      raw = _jsLevel().toDartDouble;
    } catch (_) {}
    // Фоновый шум ниже порога не считаем голосом; плавно поднимаем и опускаем столбики.
    final target = ((raw - 0.05) / 0.35).clamp(0.0, 1.0);
    _smoothLevel = target > _smoothLevel
        ? _smoothLevel + (target - _smoothLevel) * 0.6
        : _smoothLevel + (target - _smoothLevel) * 0.25;
    _level.value = _smoothLevel;
  }

  /// Раз в секунду: ответил ли собеседник, его статус и таймер.
  Future<void> _tick(Timer _) async {
    if (!mounted || !_joined) return;
    if (_connectedAt == null && _jsIsConnected().toDart) {
      _connectedAt = DateTime.now();
    }
    if (_connectedAt == null && _peer != 'declined' && !_polling) {
      _polling = true;
      try {
        final res = await Supabase.instance.client
            .rpc('call_peer_status', params: {'p_channel': widget.channel});
        if (mounted && res is String) setState(() => _peer = res);
      } catch (_) {
        // Статус не пришёл: покажем «Вызов» до ответа.
      } finally {
        _polling = false;
      }
    }
    if (!mounted) return;
    setState(() {
      if (_connectedAt != null) _elapsed = DateTime.now().difference(_connectedAt!);
    });
  }

  Future<void> _toggleMic() async {
    if (!_joined) return;
    final next = !_muted;
    await _jsSetMic(next.toJS).toDart;
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _hangUp() async {
    _ticker?.cancel();
    _levelTimer?.cancel();
    if (_joined) {
      try {
        await _jsLeave().toDart;
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _levelTimer?.cancel();
    _level.dispose();
    if (activeCallChannel == widget.channel) activeCallChannel = null;
    if (_joined) {
      _jsLeave().toDart.ignore();
    }
    super.dispose();
  }

  String get _statusText {
    if (_error != null) return _error!;
    if (_connectedAt != null) return _formatDuration(_elapsed);
    if (!_joined) return tr('Подключение…', 'Пайваст…');
    if (_peer == 'declined') return tr('Звонок отклонён', 'Занг рад шуд');
    if (_peer == 'ringing') return tr('Гудки…', 'Занги…');
    if (_peer == 'answered') return tr('Подключение…', 'Пайваст…');
    return tr('Вызов…', 'Занг…');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CallBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 28),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: kCallGold, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: kCallGold.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 1),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                Text(widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(_statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                const SizedBox(height: 24),
                VoiceBars(level: _level),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: const Color(0xFF2FB58A).withValues(alpha: 0.3)),
                  ),
                  child: _CallAction(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? tr('Включить', 'Фаъол') : tr('Без звука', 'Хомӯш'),
                    onTap: _toggleMic,
                  ),
                ),
                const SizedBox(height: 28),
                PulseRings(
                  color: const Color(0xFFE0302F),
                  child: GestureDetector(
                    onTap: _hangUp,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE0302F),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE0302F).withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr('Бросить', 'Партофтан'), style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
