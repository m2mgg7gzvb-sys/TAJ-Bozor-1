import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'notify_store.dart';
import 'theme.dart';

/// Статусы обращения: зелёный — ждёт ответа, жёлтый — на помощи, красный — отвечено.
const _statusLabel = {
  'waiting': 'В ожидании',
  'in_progress': 'На помощи',
  'answered': 'Отвечено',
};
const _statusColor = {
  'waiting': Color(0xFF2E9E5B),
  'in_progress': Color(0xFFF2B600),
  'answered': Color(0xFFE53935),
};
const _statusOrder = {'waiting': 0, 'in_progress': 1, 'answered': 2};

/// Все обращения пользователей в поддержку (только для сотрудников).
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  bool _super = false;

  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    final me = db.auth.currentUser?.id ?? '';
    if (me.isNotEmpty) {
      final prof = await db.from('profiles').select('is_super_admin').eq('id', me).maybeSingle();
      _super = prof?['is_super_admin'] == true;
    }
    final rows = await db
        .from('conversations')
        .select('id, status, buyer_id, created_at')
        .eq('kind', 'support')
        .neq('buyer_id', me)
        .order('created_at', ascending: false);
    final items = List<Map<String, dynamic>>.from(rows);
    items.sort((a, b) {
      final sa = _statusOrder[a['status']] ?? 0;
      final sb = _statusOrder[b['status']] ?? 0;
      return sa.compareTo(sb);
    });
    return items;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _setStatus(String id, String status) async {
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({'status': status})
          .eq('id', id);
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сменить статус')),
      );
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: id,
          title: 'Обращение',
          staffTicket: true,
          canFinish: _super,
        ),
      ),
    );
    if (mounted) _reload();
    refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обращения')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ]);
            }
            if (snap.hasError) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Не удалось загрузить обращения', textAlign: TextAlign.center),
                ),
              ]);
            }
            final items = snap.data ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Зелёный — ждёт ответа, жёлтый — на помощи, красный — завершено. '
                  'Завершённые обращения открывает только главный сотрудник.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Обращений пока нет', style: TextStyle(color: AppColors.muted)),
                  )
                else
                  for (final c in items) ...[
                    _ticketTile(c),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ticketTile(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final status = (c['status'] as String?) ?? 'waiting';
    final buyer = (c['buyer_id'] as String?) ?? '';
    final short = buyer.length >= 6 ? buyer.substring(0, 6) : buyer;
    // Завершённое обращение младший админ видит, но открыть не может
    final closed = status == 'answered' && !_super;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: unreadChats,
      builder: (_, unread, __) {
        final hasNew = unread.contains(id);
        return Material(
          color: closed ? const Color(0xFFEDEFEE) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            onTap: closed ? null : () => _open(id),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _statusColor[status] ?? Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            title: Text('Обращение · $short', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              _statusLabel[status] ?? status,
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasNew)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                if (hasNew) const SizedBox(width: 4),
                if (_super) PopupMenuButton<String>(
                  tooltip: 'Статус',
                  onSelected: (s) => _setStatus(id, s),
                  itemBuilder: (_) => [
                    for (final e in _statusLabel.entries)
                      if (_super || e.key != 'answered')
                        PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
