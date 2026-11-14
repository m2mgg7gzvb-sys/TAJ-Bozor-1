import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Уведомления пользователя: например, «заказан звонок» с номером покупателя.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id;
    if (me == null) return [];
    final rows = await db
        .from('notifications')
        .select('id, title, body, is_read, created_at, kind, data, listing_id')
        .eq('user_id', me)
        .order('created_at', ascending: false)
        .limit(100);
    final items = List<Map<String, dynamic>>.from(rows);
    // Непрочитанные отмечаем прочитанными, когда человек открыл экран.
    final unread = items.where((n) => n['is_read'] == false).map((n) => n['id']).toList();
    if (unread.isNotEmpty) {
      try {
        await db.from('notifications').update({'is_read': true}).inFilter('id', unread);
      } catch (_) {
        // Не критично: просто останутся непрочитанными.
      }
    }
    return items;
  }

  String _when(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('Повторить'),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('Пока новых уведомлений нет', style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = items[i];
              final unread = n['is_read'] == false;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openFromNotification(n),
                child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: unread ? const Color(0xFFE8F3EE) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n['kind'] == 'incoming_call')
                      _callBody(n)
                    else ...[
                      Row(
                        children: [
                          // Красная точка: уведомление было непрочитанным, когда экран открыли.
                          if (unread) ...[
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              (n['title'] as String?) ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      if ((n['body'] as String?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text((n['body'] as String?)!, style: const TextStyle(fontSize: 15)),
                      ],
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _when(n['created_at'] as String?),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Входящий звонок: имя сверху, снизу «Звонок» (состоялся, стрелка вверх)
  /// или «Пропущенный» (красным, стрелка вниз).
  Widget _callBody(Map<String, dynamic> n) {
    final data = (n['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final caller = (data['caller_name'] as String?)?.trim();
    final name = (caller == null || caller.isEmpty) ? 'Звонит пользователь' : caller;
    final answered = data['status'] == 'answered';
    final color = answered ? AppColors.ink : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              answered ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              answered ? 'Звонок' : 'Пропущенный',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ],
    );
  }

  /// Уведомление про объявление открывает это объявление.
  Future<void> _openFromNotification(Map<String, dynamic> n) async {
    final id = n['listing_id'] as String?;
    if (id == null) return;
    final row = await Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(item: Map<String, dynamic>.from(row))),
    );
  }
}
