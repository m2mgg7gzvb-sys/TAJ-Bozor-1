import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'theme.dart';

/// Вкладка «Сообщения» для вошедшего: поддержка, уведомления и переписки.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late Future<List<Map<String, dynamic>>> _chats = _loadChats();

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final rows = await Supabase.instance.client
        .from('conversations')
        .select('id, kind, listing_id, buyer_id, seller_id, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _chats = _loadChats());

  Future<void> _openChat({required String id, required String title}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: title)),
    );
    if (mounted) _reload();
  }

  Future<void> _openSupport() async {
    try {
      final id = await findOrCreateConversation(kind: 'support');
      if (!mounted) return;
      await _openChat(id: id, title: 'Поддержка');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть чат поддержки')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: RefreshIndicator(
        onRefresh: () async {
          final f = _loadChats();
          setState(() => _chats = f);
          await f;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _chats,
          builder: (context, snap) {
            final chats = snap.data ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Закреплённые разделы сверху
                _Tile(
                  icon: Icons.support_agent_rounded,
                  title: 'Поддержка',
                  subtitle: 'Чат с командой TAJ Bozor',
                  onTap: _openSupport,
                ),
                const SizedBox(height: 10),
                const _Tile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Уведомления',
                  subtitle: 'Пока новых уведомлений нет',
                ),
                const SizedBox(height: 22),
                const Text('Переписки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (snap.connectionState != ConnectionState.done)
                  const Center(
                    child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                  )
                else if (snap.hasError)
                  const Text('Не удалось загрузить переписки', style: TextStyle(color: AppColors.muted))
                else if (chats.where((c) => c['kind'] != 'support').isEmpty)
                  const Text(
                    'Здесь появятся переписки с продавцами и покупателями',
                    style: TextStyle(color: AppColors.muted),
                  )
                else
                  for (final c in chats.where((c) => c['kind'] != 'support')) ...[
                    _Tile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: _chatTitle(c),
                      subtitle: 'Открыть переписку',
                      onTap: () => _openChat(id: c['id'] as String, title: _chatTitle(c)),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _chatTitle(Map<String, dynamic> c) {
  if (c['kind'] == 'support') return 'Поддержка';
  final me = Supabase.instance.client.auth.currentUser?.id;
  return c['seller_id'] == me ? 'Покупатель по объявлению' : 'Продавец по объявлению';
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: CircleAvatar(
          backgroundColor: AppColors.mint,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
