import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'notify_store.dart';
import 'theme.dart';

/// Статусы обращения: зелёный — ждёт ответа, жёлтый — на помощи, красный — завершено.
const _statusLabel = {
  'waiting': 'В ожидании',
  'in_progress': 'На помощи',
  'answered': 'Завершено',
};
const _statusColor = {
  'waiting': Color(0xFF2E9E5B),
  'in_progress': Color(0xFFF2B600),
  'answered': Color(0xFFE53935),
};
const _statusOrder = {'waiting': 0, 'in_progress': 1, 'answered': 2};

/// Все обращения пользователей в поддержку (только для сотрудников).
/// Список обновляется в реальном времени: изменения с других аккаунтов видны сразу.
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _db = Supabase.instance.client;
  late final String _me = _db.auth.currentUser?.id ?? '';
  late final Stream<List<Map<String, dynamic>>> _stream =
      _db.from('conversations').stream(primaryKey: ['id']).eq('kind', 'support');
  bool _super = false;

  @override
  void initState() {
    super.initState();
    _loadSuper();
  }

  Future<void> _loadSuper() async {
    if (_me.isEmpty) return;
    try {
      final prof = await _db.from('profiles').select('is_super_admin').eq('id', _me).maybeSingle();
      if (mounted) setState(() => _super = prof?['is_super_admin'] == true);
    } catch (_) {
      // Без этого флага просто не покажем главные права
    }
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> rows) {
    final items = rows.toList();
    items.sort((a, b) {
      final sa = _statusOrder[a['status']] ?? 0;
      final sb = _statusOrder[b['status']] ?? 0;
      if (sa != sb) return sa.compareTo(sb);
      return (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? '');
    });
    return items;
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await _db.rpc('set_ticket_status', params: {'cid': id, 'new_status': status});
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
          canFinish: true,
        ),
      ),
    );
    refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обращения')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Не удалось загрузить обращения', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = _sorted(snap.data!);
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
            title: Text(
              'Обращение · $short${buyer == _me ? ' (вы)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
                if (_super)
                  PopupMenuButton<String>(
                    tooltip: 'Статус',
                    onSelected: (s) => _setStatus(id, s),
                    itemBuilder: (_) => [
                      for (final e in _statusLabel.entries)
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
