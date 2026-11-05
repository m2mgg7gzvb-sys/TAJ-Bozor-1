import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

const _actionNames = <String, String>{
  'approve': 'Опубликовано',
  'freeze': 'Заморожено',
  'unfreeze': 'Разморожено',
  'block': 'Заблокировано',
  'unblock': 'Разблокировано',
  'delete': 'Удалено',
  'restore': 'Возвращено в активные',
  'report_closed': 'Жалоба закрыта',
  'report_block': 'Жалоба: объявление заблокировано',
};

/// Меняет статус объявления от имени админа, сохраняет причину для владельца и пишет в журнал.
Future<void> adminSetStatus({
  required String listingId,
  required String status,
  required String action,
  String? note,
}) async {
  final db = Supabase.instance.client;
  final listing = await db.from('listings').select('user_id, title').eq('id', listingId).maybeSingle();
  await db.from('listings').update({'status': status, 'admin_note': note}).eq('id', listingId);
  await db.from('admin_log').insert({'listing_id': listingId, 'action': action, 'note': note});
  await _notifyOwner(listing, action, note);
}

/// Уведомление владельцу о решении по объявлению. Ошибка уведомления не отменяет решение.
Future<void> _notifyOwner(Map<String, dynamic>? listing, String action, String? note) async {
  final ownerId = listing?['user_id'] as String?;
  final title = (listing?['title'] as String?) ?? '';
  final texts = <String, (String, String)>{
    'approve': ('Объявление опубликовано', '«$title» успешно прошло проверку и опубликовано.'),
    'block': ('Объявление заблокировано', '«$title» заблокировано администрацией.${note == null ? '' : ' Причина: $note'}'),
    'freeze': ('Объявление заморожено', '«$title» временно скрыто администрацией.${note == null ? '' : ' Причина: $note'}'),
  };
  final t = texts[action];
  if (ownerId == null || t == null) return;
  try {
    await Supabase.instance.client.from('notifications').insert({
      'user_id': ownerId,
      'title': t.$1,
      'body': t.$2,
      'is_read': false,
    });
  } catch (_) {
    // Уведомление не критично для решения админа
  }
}

/// Окно с причиной. Возвращает текст (может быть пустым) или null, если отменили.
Future<String?> askReason(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Причина (увидит владелец, можно пропустить)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Далее')),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}

/// Журнал действий админов.
class AdminLogScreen extends StatefulWidget {
  const AdminLogScreen({super.key});

  @override
  State<AdminLogScreen> createState() => _AdminLogScreenState();
}

class _AdminLogScreenState extends State<AdminLogScreen> {
  late final Future<List<Map<String, dynamic>>> _future = Supabase.instance.client
      .from('admin_log')
      .select('action, note, created_at, listing_id')
      .order('created_at', ascending: false)
      .limit(200)
      .then((rows) => List<Map<String, dynamic>>.from(rows));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Журнал действий')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Не удалось загрузить журнал'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('Действий пока нет', style: TextStyle(color: AppColors.muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = items[i];
              final action = (e['action'] as String?) ?? '';
              final note = e['note'] as String?;
              final date = ((e['created_at'] as String?) ?? '').replaceFirst('T', ' ').split('.').first;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_actionNames[action] ?? action, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (note != null && note.isNotEmpty)
                      Text('Причина: $note', style: const TextStyle(fontSize: 13)),
                    Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
