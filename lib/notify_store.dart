import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Навигатор приложения: нужен, чтобы показывать баннер поверх любого экрана.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Есть непрочитанное (уведомления или сообщения) — для красной точки на вкладке.
final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

/// Переписки, где есть непрочитанные сообщения — для точки у переписки.
final ValueNotifier<Set<String>> unreadChats = ValueNotifier<Set<String>>(<String>{});

RealtimeChannel? _channel;
StreamSubscription<AuthState>? _authSub;

/// Запускаем один раз при старте приложения: следим за входом и выходом.
void startNotifications() {
  _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    _onSession(state.session);
  });
  _onSession(Supabase.instance.client.auth.currentSession);
}

void _onSession(Session? session) {
  _channel?.unsubscribe();
  _channel = null;
  if (session == null) {
    hasUnread.value = false;
    unreadChats.value = <String>{};
    return;
  }
  final db = Supabase.instance.client;
  final me = session.user.id;
  _channel = db.channel('user-$me')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: me,
      ),
      callback: (payload) {
        final row = payload.newRecord;
        showTopBanner(
          (row['title'] as String?) ?? 'Уведомление',
          (row['body'] as String?) ?? '',
        );
        refreshUnread();
      },
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final row = payload.newRecord;
        if (row['sender_id'] != me) {
          showTopBanner('Новое сообщение', (row['body'] as String?) ?? '');
        }
        refreshUnread();
      },
    )
    ..subscribe();
  refreshUnread();
}

/// Пересчитываем непрочитанное: уведомления и переписки.
Future<void> refreshUnread() async {
  final db = Supabase.instance.client;
  final me = db.auth.currentUser?.id;
  if (me == null) return;
  try {
    final notes = await db
        .from('notifications')
        .select('id')
        .eq('user_id', me)
        .eq('is_read', false);
    final convs = List<Map<String, dynamic>>.from(await db.from('conversations').select('id'));
    final prefs = await SharedPreferences.getInstance();
    final unread = <String>{};
    for (final c in convs) {
      final id = c['id'] as String;
      final last = List<Map<String, dynamic>>.from(await db
          .from('messages')
          .select('sender_id, created_at')
          .eq('conversation_id', id)
          .order('created_at', ascending: false)
          .limit(1));
      if (last.isEmpty) continue;
      final m = last.first;
      if (m['sender_id'] == me) continue;
      final readAt = prefs.getString('read_$id');
      final sentAt = DateTime.parse(m['created_at'] as String);
      if (readAt == null || sentAt.isAfter(DateTime.parse(readAt))) {
        unread.add(id);
      }
    }
    unreadChats.value = unread;
    hasUnread.value = notes.isNotEmpty || unread.isNotEmpty;
  } catch (_) {
    // Без подсчёта точка просто не изменится.
  }
}

/// Отмечаем переписку прочитанной, когда её открыли.
Future<void> markChatRead(String conversationId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('read_$conversationId', DateTime.now().toUtc().toIso8601String());
  } catch (_) {
    // Не критично.
  }
  await refreshUnread();
}

/// Баннер сверху экрана на 5 секунд; нажатие закрывает его.
void showTopBanner(String title, String body) {
  final overlay = appNavigatorKey.currentState?.overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  void close() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: close,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 5), close);
}
