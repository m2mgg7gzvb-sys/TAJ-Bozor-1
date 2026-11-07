import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Фото из чата. Хранится в закрытом хранилище, поэтому ссылка подписывается на час.
class ChatImage extends StatelessWidget {
  const ChatImage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: Supabase.instance.client.storage.from('chat-attachments').createSignedUrl(path, 3600),
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
            width: 220,
            height: 120,
            child: Center(child: Text('Не удалось загрузить фото')),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            width: 220,
            height: 150,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            snap.data!,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 220,
              height: 120,
              child: Center(child: Text('Не удалось загрузить фото')),
            ),
          ),
        );
      },
    );
  }
}
