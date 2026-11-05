import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'listing_utils.dart';
import 'admin_listings_screen.dart';
import 'admin_log.dart';
import 'admin_threads.dart';
import 'listing_reports.dart';
import 'moderation_screen.dart';
import 'notify_store.dart';
import 'notifications_screen.dart';
import 'support_tickets_screen.dart';
import 'theme.dart';
import 'user_profile_screen.dart';

/// Вкладка «Сообщения» для вошедшего: поддержка, уведомления и переписки.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  late Future<List<Map<String, dynamic>>> _chats = _loadChats();
  bool _staff = false;

  /// Счётчики для админа: 'mod' — объявления на проверке, 'rep' — открытые жалобы, 'sup' — новые обращения.
  Map<String, int> _badges = {};

  /// Есть ли непрочитанные уведомления: тогда у плитки «Уведомления» горит точка.
  bool _hasUnreadNotes = false;

  Future<void> _loadNotesDot() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', me)
          .eq('is_read', false)
          .limit(1);
      if (!mounted) return;
      setState(() => _hasUnreadNotes = rows.isNotEmpty);
    } catch (_) {
      // Точка не критична
    }
  }

  Future<void> _loadBadges() async {
    final db = Supabase.instance.client;
    try {
      final mod = await db.from('listings').select('id').eq('status', 'moderation');
      final rep = await db.from('listing_reports').select('id').eq('status', 'open');
      final sup = await db.from('conversations').select('id').eq('kind', 'support').eq('status', 'waiting');
      if (!mounted) return;
      setState(() => _badges = {'mod': mod.length, 'rep': rep.length, 'sup': sup.length});
    } catch (_) {
      // Счётчики не критичны: без них список работает как раньше
    }
  }

  /// Переписки вместе с объявлением (_listing) и собеседником (_other) для карточек.
  Future<List<Map<String, dynamic>>> _loadChats() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    final rows = List<Map<String, dynamic>>.from(await db
        .from('conversations')
        .select('id, kind, listing_id, buyer_id, seller_id, created_at')
        .order('created_at', ascending: false));
    if (me != null) {
      final prof = await db.from('profiles').select('is_admin').eq('id', me).maybeSingle();
      _staff = prof?['is_admin'] == true;
    }

    final listingIds = <String>{
      for (final c in rows)
        if (c['listing_id'] != null) c['listing_id'] as String,
    };
    final otherIds = <String>{
      for (final c in rows)
        if (c['kind'] != 'support')
          if ((c['buyer_id'] == me ? c['seller_id'] : c['buyer_id']) is String)
            (c['buyer_id'] == me ? c['seller_id'] : c['buyer_id']) as String,
    };

    final listings = <String, Map<String, dynamic>>{};
    if (listingIds.isNotEmpty) {
      final rs = List<Map<String, dynamic>>.from(
          await db.from('listings').select(listingSelect).inFilter('id', listingIds.toList()));
      for (final r in rs) {
        listings[r['id'] as String] = r;
      }
    }
    final people = <String, Map<String, dynamic>>{};
    if (otherIds.isNotEmpty) {
      final ps = List<Map<String, dynamic>>.from(await db
          .from('profiles')
          .select('id, name, avatar_url')
          .inFilter('id', otherIds.toList()));
      for (final p in ps) {
        people[p['id'] as String] = p;
      }
    }
    for (final c in rows) {
      final otherId = c['buyer_id'] == me ? c['seller_id'] : c['buyer_id'];
      c['_listing'] = c['listing_id'] == null ? null : listings[c['listing_id'] as String];
      c['_other'] = otherId == null ? null : people[otherId as String];
    }
    if (_staff) _loadBadges();
    _loadNotesDot();
    return rows;
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
                  badge: _staff ? _badges['sup'] : null,
                  onTap: _staff
                      ? () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()))
                          .then((_) => _reload())
                      : _openSupport,
                ),
                const SizedBox(height: 10),
                if (_staff) ...[
                  _Tile(
                    icon: Icons.fact_check_outlined,
                    title: 'Проверка объявлений',
                    subtitle: 'Новые и изменённые объявления',
                    badge: _badges['mod'],
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ModerationScreen()))
                        .then((_) => _reload()),
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Все объявления',
                    subtitle: 'Заморозка, блокировка, удаление',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminListingsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    icon: Icons.flag_outlined,
                    title: 'Жалобы',
                    subtitle: 'Жалобы пользователей на объявления',
                    badge: _badges['rep'],
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ReportsScreen()))
                        .then((_) => _reload()),
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    icon: Icons.history_rounded,
                    title: 'Журнал действий',
                    subtitle: 'Кто и что менял у объявлений',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminLogScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Tile(
                    icon: Icons.manage_search_rounded,
                    title: 'Поиск по ID',
                    subtitle: 'Открыть объявление и управлять им',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminChatsScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _Tile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Уведомления',
                  subtitle: 'Заказы звонков и другие сообщения',
                  dot: _hasUnreadNotes,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ).then((_) => _loadNotesDot()),
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
                  // Непрочитанные переписки всегда сверху
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: unreadChats,
                    builder: (_, unread, __) {
                      final list = chats.where((c) => c['kind'] != 'support').toList()
                        ..sort((a, b) {
                          final ua = unread.contains(a['id']) ? 0 : 1;
                          final ub = unread.contains(b['id']) ? 0 : 1;
                          return ua.compareTo(ub);
                        });
                      return Column(
                        children: [
                          for (final c in list) ...[
                            _ChatTile(
                              chat: c,
                              unread: unread.contains(c['id'] as String),
                              onTap: () => _openChat(
                                id: c['id'] as String,
                                title: _otherName(c),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Имя собеседника для заголовка переписки.
String _otherName(Map<String, dynamic> c) {
  final other = c['_other'] as Map<String, dynamic>?;
  final name = ((other?['name'] as String?) ?? '').trim();
  return name.isEmpty ? 'Пользователь' : name;
}

/// Карточка переписки: фото объявления, имя собеседника и название объявления.
class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.unread, required this.onTap});

  final Map<String, dynamic> chat;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listing = chat['_listing'] as Map<String, dynamic>?;
    final photo = listing == null ? null : photoUrl(listing);
    final listingTitle = (listing?['title'] as String?) ?? 'Объявление удалено';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        // Переписка из профиля (без объявления) — аватар собеседника
        leading: listing == null
            ? UserAvatar(
                name: _otherName(chat),
                url: (chat['_other'] as Map<String, dynamic>?)?['avatar_url'] as String?,
                radius: 28,
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: photo == null
                      ? Container(
                          color: AppColors.mint,
                          child: const Icon(Icons.image_outlined, color: AppColors.primary),
                        )
                      : Image.network(photo, fit: BoxFit.cover),
                ),
              ),
        title: Text(
          _otherName(chat),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700),
        ),
        subtitle: Text(
          listing == null ? 'Личная переписка' : listingTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unread)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            if (unread) const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, this.onTap, this.badge, this.dot = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Число новых записей; при 0 или null метка не показывается.
  final int? badge;

  /// Красная точка для непрочитанного.
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null && badge! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            if (badge != null && badge! > 0) const SizedBox(width: 8),
            if (dot)
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
