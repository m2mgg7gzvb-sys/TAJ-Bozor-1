import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Голосовое сообщение: воспроизводится по подписанной ссылке из закрытого хранилища.
class ChatAudioTile extends StatefulWidget {
  const ChatAudioTile({super.key, required this.path, required this.mine});

  final String path;
  final bool mine;

  @override
  State<ChatAudioTile> createState() => _ChatAudioTileState();
}

class _ChatAudioTileState extends State<ChatAudioTile> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final url = await Supabase.instance.client.storage
        .from('chat-attachments')
        .createSignedUrl(widget.path, 3600);
    await _player.play(UrlSource(url));
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mine ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: color,
            size: 32,
          ),
        ),
        Text('Голосовое', style: TextStyle(color: color)),
      ],
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
