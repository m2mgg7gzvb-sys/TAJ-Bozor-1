import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'glass_widgets.dart';
import 'lang_store.dart';
import 'theme.dart';
import 'user_profile_screen.dart';

_userReasons = [tr('Мошенничество', 'Фиребгарӣ'), tr('Оскорбления', 'Таҳқир'), tr('Спам', 'Спам'), tr('Фейковый профиль', 'Профили қалбакӣ'), tr('Другое', 'Дигар')];

/// Окно жалобы на пользователя. Сохраняет жалобу в таблицу complaints.
Future<void> showUserComplaintDialog(BuildContext context, String userId) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => GlassDialog(
      title: tr('Пожаловаться на пользователя', 'Аз корбар шикоят кардан'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in _userReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: AppColors.ink,
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                onPressed: () => Navigator.pop(ctx, r),
                child: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Supabase.instance.client.from('complaints').insert({
      'reporter_id': Supabase.instance.client.auth.currentUser!.id,
      'target_user_id': userId,
      'reason': reason,
    });
    messenger.showSnackBar(SnackBar(
      content: Text(tr('Спасибо, жалоба отправлена администрации', 'Ташаккур, шикоят ба маъмурият фиристода шуд')),
    ));
  } catch (_) {
    messenger.showSnackBar(SnackBar(
      content: Text(tr('Не удалось отправить жалобу', 'Фиристодани шикоят муяссар нашуд')),
    ));
  }
}

/// Жалобы на пользователей для админов: открыть профиль или закрыть жалобу.
class UserComplaintsScreen extends StatefulWidget {
  const UserComplaintsScreen({super.key});

  @override
  State<UserComplaintsScreen> createState() => _UserComplaintsScreenState();
}

class _UserComplaintsScreenState extends State<UserComplaintsScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = List<Map<String, dynamic>>.from(await _db
        .from('complaints')
        .select('id, reason, comment, created_at, target_user_id')
        .eq('status', 'open')
        .order('created_at', ascending: false));
    final ids = {for (final r in rows) if (r['target_user_id'] != null) r['target_user_id'] as String};
    if (ids.isNotEmpty) {
      final ps = List<Map<String, dynamic>>.from(
          await _db.from('profiles').select('id, name').inFilter('id', ids.toList()));
      final byId = {for (final p in ps) p['id'] as String: p};
      for (final r in rows) {
        r['target'] = byId[r['target_user_id'] as String?];
      }
    }
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _close(String id) async {
    try {
      await _db.from('complaints').update({'status': 'dismissed'}).eq('id', id);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Не удалось закрыть жалобу', 'Пӯшидани шикоят муяссар нашуд'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Жалобы на пользователей', 'Шикоятҳо ба корбарон'))),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text(tr('Не удалось загрузить жалобы', 'Бор кардани шикоятҳо муяссар нашуд')));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(tr('Открытых жалоб нет', 'Шикоятҳои кушода нест'), style: TextStyle(color: AppColors.muted))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = rows[i];
                final name = ((r['target'] as Map?)?['name'] as String?) ?? tr('Пользователь', 'Корбар');
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(r['reason'] as String? ?? '', style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                final uid = r['target_user_id'] as String?;
                                if (uid == null) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => UserProfileScreen(userId: uid)),
                                );
                              },
                              child: Text(tr('Профиль', 'Профил')),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _close(r['id'] as String),
                              child: Text(tr('Закрыть', 'Пӯшидан')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
