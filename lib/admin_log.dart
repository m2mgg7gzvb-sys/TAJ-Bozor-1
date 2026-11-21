import 'lang_store.dart';
import 'package:flutter/material.dart';

import 'glass_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_threads.dart';
import 'theme.dart';
import 'green_button.dart';

final adminActionNames = <String, String>{
  'approve': tr('Опубликовано', 'Нашр шуд'),
  'freeze': tr('Заморожено', 'Музд шудааст'),
  'unfreeze': tr('Разморожено', 'Аз музд баромад'),
  'block': tr('Заблокировано', 'Маҳдуд шудааст'),
  'unblock': tr('Разблокировано', 'Маҳдудият бардошта шуд'),
  'delete': tr('Удалено', 'Нест карда шуд'),
  'restore': tr('Возвращено в активные', 'Ба фаъолон баргардонида шуд'),
  'report_closed': tr('Жалоба закрыта', 'Шикоят пӯшида шуд'),
  'report_block': tr('Жалоба: объявление заблокировано', 'Шикоят: эълон маҳдуд шуд'),
  'message': tr('Сообщение администратора', 'Паёми администратор'),
  'profile_hide': tr('Скрыто через профиль пользователя', 'Аз профили корбар пинҳон шуд'),
  'edit': tr('Изменено администратором', 'Аз ҷониби администратор тағйир ёфт'),
  'user_block': tr('Пользователь: блокировка', 'Корбар: маҳдуд кардан'),
  'user_admin_role': tr('Пользователь: права админа', 'Корбар: ҳуқуқҳои админ'),
  'user_verified': tr('Пользователь: бейдж «Проверено»', 'Корбар: нишони «Тасдиқшуда»'),
};

/// Меняет статус объявления от имени админа, сохраняет причину для владельца и пишет в журнал.
Future<void> adminSetStatus({
  required String listingId,
  required String status,
  required String action,
  String? note,
}) async {
  final db = Supabase.instance.client;
  final listing = await db
      .from('listings')
      .select('user_id, title, status')
      .eq('id', listingId)
      .maybeSingle();
  await db.from('listings').update({'status': status, 'admin_note': note}).eq('id', listingId);
  await db.from('admin_log').insert({
    'listing_id': listingId,
    'action': action,
    'note': note,
    'from_value': listing?['status'],
    'to_value': status,
  });
  await _notifyOwner(listing, action, note);
}

/// Уведомление владельцу о решении по объявлению. Ошибка уведомления не отменяет решение.
Future<void> _notifyOwner(Map<String, dynamic>? listing, String action, String? note) async {
  final ownerId = listing?['user_id'] as String?;
  final title = (listing?['title'] as String?) ?? '';
  final texts = <String, (String, String)>{
    'approve': (tr('Объявление опубликовано', 'Эълон нашр шуд'), tr('«$title» успешно прошло проверку и опубликовано.', '«$title» санҷишро бомуваффақият гузашт ва нашр шуд.')),
    'block': (tr('Объявление заблокировано', 'Эълон маҳдуд карда шуд'), '«$title» заблокировано администрацией.${note == null ? '' : tr(' Причина: $note', ' Сабаб: $note')}'),
    'freeze': (tr('Объявление заморожено', 'Эълон музд карда шуд'), '«$title» временно скрыто администрацией.${note == null ? '' : tr(' Причина: $note', ' Сабаб: $note')}'),
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
      'title': tr('Сообщение от администратора', 'Паём аз администратор'),
      'body': tr('По объявлению «${listing?['title'] ?? ''}»: $text', 'Ба эълони «${listing?['title'] ?? ''}»: $text'),
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
          hintText: tr('Причина (увидит владелец, можно пропустить)', 'Сабаб (соҳиб мебинад, метавонед гузаред)'),
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
          child: Text(tr('Отмена', 'Бекор'), style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        GreenButton(
height: 50,

          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(tr('Далее', 'Идома'), style: TextStyle(fontWeight: FontWeight.w700)),
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
        .select('action, note, created_at, listing_id, admin_name, admin_public_id, listing_public_id, from_value, to_value')
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),title: Text(tr('Журнал действий', 'Журнали амалҳо'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(tr('Не удалось загрузить журнал', 'Бор кардани журнал муяссар нашуд')));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(child: Text(tr('Действий пока нет', 'Ҳоло амал нест'), style: TextStyle(color: AppColors.muted)));
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
                decoration: glowDecoration(radius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e['admin_name'] ?? tr('Админ', 'Админ')} · ${e['admin_public_id'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(adminActionNames[action] ?? action, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (e['from_value'] != null || e['to_value'] != null)
                      Text('${e['from_value'] ?? '—'} → ${e['to_value'] ?? '—'}',
                          style: const TextStyle(fontSize: 13)),
                    if (listingId != null)
                      Text(tr('Объявление: ${e['listing_public_id'] ?? e['no'] ?? '—'}', 'Эълон: ${e['listing_public_id'] ?? e['no'] ?? '—'}'),
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    if (note != null && note.isNotEmpty)
                      Text(action == 'message' ? note : tr('Причина: $note', 'Сабаб: $note'), style: TextStyle(fontSize: 13)),
                    Text(date, style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
