import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Голосовое сообщение: кнопка «играть», волна с бегущим прогрессом и длительность.
/// Воспроизводится по подписанной ссылке из закрытого хранилища.
class ChatAudioTile extends StatefulWidget {
  const ChatAudioTile({super.key, required this.path, required this.mine});

  final String path;
  final bool mine;

  @override
  State<ChatAudioTile> createState() => _ChatAudioTileState();
}

class _ChatAudioTileState extends State<ChatAudioTile> {
  static const _barCount = 28;

  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late final List<double> _bars = _makeBars(widget.path);
  Future<String>? _urlFuture; // подписанная ссылка: запрашивается заранее и кэшируется

  /// Высоты столбиков волны: одинаковые для одного и того же файла.
  static List<double> _makeBars(String seed) {
    final r = math.Random(seed.hashCode);
    return List.generate(_barCount, (_) => 0.3 + r.nextDouble() * 0.7);
  }

  @override
  void initState() {
    super.initState();
    _signed(); // ссылку получаем сразу, чтобы по нажатию не ждать сеть
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<String> _signed() {
    return _urlFuture ??= Supabase.instance.client.storage
        .from('chat-attachments')
        .createSignedUrl(widget.path, 3600);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    // Значок меняется сразу, звук начинается, как только придёт ссылка.
    setState(() => _playing = true);
    try {
      final url = await _signed();
      await _player.play(UrlSource(url));
    } catch (_) {
      _urlFuture = null;
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _seek(double fraction) async {
    if (_dur.inMilliseconds == 0) return;
    await _player.seek(Duration(milliseconds: (_dur.inMilliseconds * fraction).round()));
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.mine ? AppColors.deep : AppColors.primary;
    final progress = _dur.inMilliseconds == 0
        ? 0.0
        : (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0);
    final shown = (_playing || _pos > Duration.zero) ? _pos : _dur;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, accent.withValues(alpha: 0.8)],
                ),
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, c) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _seek((d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                    child: SizedBox(
                      height: 26,
                      child: Row(
                        children: [
                          for (var i = 0; i < _barCount; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Align(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    height: 4 + 20 * _bars[i],
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: (i / _barCount) <= progress
                                          ? accent
                                          : accent.withValues(alpha: 0.28),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fmt(shown),
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

/// Файл из чата: открывается по подписанной ссылке.
class ChatFileTile extends StatelessWidget {
  const ChatFileTile({super.key, required this.path, required this.name, required this.mine});

  final String path;
  final String name;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final color = mine ? Colors.white : AppColors.ink;
    return InkWell(
      onTap: () async {
        final url = await Supabase.instance.client.storage
            .from('chat-attachments')
            .createSignedUrl(path, 3600);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: TextStyle(color: color, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}
