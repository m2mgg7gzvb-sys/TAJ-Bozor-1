import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'notify_store.dart';
import 'notifications_screen.dart';
import 'support_tickets_screen.dart';
import 'theme.dart';

/// Вкладка «Сообщения» для вошедшего: поддержка, уведомления и переписки.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late Future<List<Map<String, dynamic>>> _chats = _loadChats();
  bool _staff = false;

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    final rows = await db
        .from('conversations')
        .select('id, kind, listing_id, buyer_id, seller_id, created_at')
        .order('created_at', ascending: false);
    if (me != null) {
      final prof = await db.from('profiles').select('is_admin').eq('id', me).maybeSingle();
      _staff = prof?['is_admin'] == true;
    }
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
    } catch (e) {
      if (!mounted) return;
      final reason = e is PostgrestException ? ': ${e.message}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть чат поддержки$reason')),
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
                  icon: _staff ? Icons.list_alt_rounded : Icons.support_agent_rounded,
                  title: _staff ? 'Обращения' : 'Поддержка',
                  subtitle: _staff ? 'Все обращения пользователей' : 'Чат с командой TAJ Bozor',
                  onTap: _staff
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
                          )
                      : _openSupport,
                ),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Уведомления',
                  subtitle: 'Заказы звонков и другие сообщения',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
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
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: unreadChats,
                      builder: (_, unread, __) => _Tile(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: _chatTitle(c),
                        subtitle: 'Открыть переписку',
                        dot: unread.contains(c['id'] as String),
                        onTap: () => _openChat(id: c['id'] as String, title: _chatTitle(c)),
                      ),
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
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (c['kind'] == 'support') {
    return c['buyer_id'] == me ? 'Поддержка' : 'Обращение пользователя';
  }
  return c['seller_id'] == me ? 'Покупатель по объявлению' : 'Продавец по объявлению';
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dot;

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
        trailing: onTap == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  if (dot) const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
      ),
    );
  }
}
