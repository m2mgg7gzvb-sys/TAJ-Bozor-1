import 'package:flutter/material.dart';

import 'glass_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_threads.dart';
import 'theme.dart';

const adminActionNames = <String, String>{
  'approve': 'Опубликовано',
  'freeze': 'Заморожено',
  'unfreeze': 'Разморожено',
  'block': 'Заблокировано',
  'unblock': 'Разблокировано',
  'delete': 'Удалено',
  'restore': 'Возвращено в активные',
  'report_closed': 'Жалоба закрыта',
  'report_block': 'Жалоба: объявление заблокировано',
  'message': 'Сообщение администратора',
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

/// Сообщение владельцу от имени администратора: пишется в журнал по объявлению и уходит уведомлением.
Future<void> adminSendMessage(String listingId, String text) async {
  final db = Supabase.instance.client;
  final listing = await db.from('listings').select('user_id, title').eq('id', listingId).maybeSingle();
  await db.from('admin_log').insert({'listing_id': listingId, 'action': 'message', 'note': text});
  final ownerId = listing?['user_id'] as String?;
  if (ownerId == null) return;
  try {
    await db.from('notifications').insert({
      'user_id': ownerId,
      'title': 'Сообщение от администратора',
      'body': 'По объявлению «${listing?['title'] ?? ''}»: $text',
      'is_read': false,
    });
  } catch (_) {
    // Сообщение в журнале уже сохранено
  }
}

/// Окно с причиной. Возвращает текст (может быть пустым) или null, если отменили.
Future<String?> askReason(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => GlassDialog(
      title: title,
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Причина (увидит владелец, можно пропустить)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Далее', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
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
  late final Future<List<Map<String, dynamic>>> _future = _load();

  /// Журнал с публичными ID объявлений.
  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    final rows = List<Map<String, dynamic>>.from(await db
        .from('admin_log')
        .select('action, note, created_at, listing_id')
        .order('created_at', ascending: false)
        .limit(200));
    final ids = rows.map((r) => r['listing_id']).whereType<String>().toSet().toList();
    if (ids.isEmpty) return rows;
    final nums = await db.from('listings').select('id, public_id').inFilter('id', ids);
    final byId = {for (final n in nums) n['id'] as String: n['public_id']};
    return [
      for (final r in rows) {...r, 'no': byId[r['listing_id']]},
    ];
  }

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
              final listingId = e['listing_id'] as String?;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: listingId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AdminThreadScreen(listingId: listingId)),
                        ),
                child: Container(
                padding: const EdgeInsets.all(12),
                decoration: cardDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(adminActionNames[action] ?? action, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (listingId != null)
                      Text('ID: ${e['no'] ?? '—'}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (note != null && note.isNotEmpty)
                      Text(action == 'message' ? note : 'Причина: $note', style: const TextStyle(fontSize: 13)),
                    Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
}
