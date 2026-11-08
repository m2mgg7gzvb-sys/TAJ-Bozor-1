import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'incoming_call_screen.dart';
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
        if (row['kind'] == 'incoming_call') {
          _showIncomingCall(row);
        } else {
          showTopBanner(
            (row['title'] as String?) ?? 'Уведомление',
            (row['body'] as String?) ?? '',
          );
        }
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
    // Для админа: новые жалобы, объявления на проверке и обращения тоже обновляют точку.
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'listing_reports',
      callback: (_) => refreshUnread(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'listings',
      callback: (_) => refreshUnread(),
    )
    ..subscribe();
  refreshUnread();
}

/// Входящий звонок: открываем экран с гудком поверх любого экрана.
void _showIncomingCall(Map<String, dynamic> row) {
  final data = row['data'];
  if (data is! Map) return;
  final channel = data['channel'] as String?;
  final callerName = (data['caller_name'] as String?) ?? 'Звонит пользователь';
  if (channel == null || channel.isEmpty) return;
  final nav = appNavigatorKey.currentState;
  if (nav == null) return;
  nav.push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(channel: channel, callerName: callerName),
    ),
  );
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
    final convs = List<Map<String, dynamic>>.from(
        await db.from('conversations').select('id, kind, status, buyer_id'));
    final prefs = await SharedPreferences.getInstance();
    final unread = <String>{};
    for (final c in convs) {
      final id = c['id'] as String;
      // Обращения сотрудника: завершённые не считаются, ожидающие считаются новыми всегда
      if (c['kind'] == 'support' && c['buyer_id'] != me) {
        if (c['status'] == 'answered') continue;
        if (c['status'] == 'waiting') {
          unread.add(id);
          continue;
        }
      }
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
    // Админу точка горит и при новых жалобах, объявлениях на проверке или обращениях.
    var staffNew = false;
    final prof = await db.from('profiles').select('is_admin').eq('id', me).maybeSingle();
    if (prof?['is_admin'] == true) {
      final mod = await db.from('listings').select('id').eq('status', 'moderation').limit(1);
      final rep = await db.from('listing_reports').select('id').eq('status', 'open').limit(1);
      final sup = await db.from('conversations').select('id').eq('kind', 'support').eq('status', 'waiting').limit(1);
      staffNew = mod.isNotEmpty || rep.isNotEmpty || sup.isNotEmpty;
    }
    hasUnread.value = notes.isNotEmpty || unread.isNotEmpty || staffNew;
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
void showTopBanner(
  String title,
  String body, {
  VoidCallback? onTap,
  String? secondaryLabel,
  VoidCallback? onSecondary,
}) {
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
              onTap: () {
                close();
                onTap?.call();
              },
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
                    if (secondaryLabel != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            close();
                            onSecondary?.call();
                          },
                          child: Text(
                            secondaryLabel,
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
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
