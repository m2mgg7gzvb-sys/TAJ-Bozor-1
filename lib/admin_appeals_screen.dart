import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';
import 'theme.dart';

/// Обжалования отзывов для админов: одобрить (отзыв удаляется) или отклонить.
class AdminAppealsScreen extends StatefulWidget {
  const AdminAppealsScreen({super.key});

  @override
  State<AdminAppealsScreen> createState() => _AdminAppealsScreenState();
}

class _AdminAppealsScreenState extends State<AdminAppealsScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = List<Map<String, dynamic>>.from(await _db
        .from('review_appeals')
        .select('id, review_id, seller_id, reason, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: true));
    final reviewIds = {for (final r in rows) if (r['review_id'] != null) r['review_id'] as String};
    final reviews = reviewIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(await _db
            .from('reviews')
            .select('id, rating, body, author_id')
            .inFilter('id', reviewIds.toList()));
    final byReview = {for (final r in reviews) r['id'] as String: r};

    final ids = <String>{
      for (final r in rows) r['seller_id'] as String,
      for (final r in reviews) r['author_id'] as String,
    };
    final profiles = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await _db.from('profiles').select('id, name').inFilter('id', ids.toList()));
    final names = {for (final p in profiles) p['id'] as String: (p['name'] as String?) ?? ''};

    for (final r in rows) {
      final review = byReview[r['review_id'] as String?];
      r['review'] = review;
      r['seller_name'] = _nameOf(names, r['seller_id'] as String);
      r['author_name'] = review == null ? '' : _nameOf(names, review['author_id'] as String);
    }
    return rows;
  }

  String _nameOf(Map<String, String> names, String id) {
    final n = (names[id] ?? '').trim();
    return n.isEmpty ? tr('Пользователь', 'Корбар') : n;
  }

  void _reload() => setState(() => _future = _load());

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _reject(String appealId) async {
    try {
      await _db.from('review_appeals').update({
        'status': 'rejected',
        'decided_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', appealId);
      _reload();
    } catch (_) {
      _snack(tr('Не удалось отклонить', 'Рад кардан муяссар нашуд'));
    }
  }

  Future<void> _accept(Map<String, dynamic> appeal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Одобрить обжалование?', 'Шикоятро қабул кунед?')),
        content: Text(tr(
          'Отзыв будет удалён. Это нельзя отменить.',
          'Бознигарӣ нест карда мешавад. Ин бозгашт надорад.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Отмена', 'Бекор'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Удалить отзыв', 'Бознигариро нест кун'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Сначала отмечаем обжалование, потом удаляем отзыв (связь с обжалованием сохраняется как история).
      await _db.from('review_appeals').update({
        'status': 'accepted',
        'decided_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', appeal['id'] as String);
      final reviewId = appeal['review_id'] as String?;
      if (reviewId != null) {
        await _db.from('reviews').delete().eq('id', reviewId);
      }
      _reload();
    } catch (_) {
      _snack(tr('Не удалось удалить отзыв', 'Нест кардани бознигарӣ муяссар нашуд'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Обжалования отзывов', 'Шикоятҳо ба бознигариҳо'))),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text(tr('Не удалось загрузить', 'Бор кардан муяссар нашуд')));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(tr('Новых обжалований нет', 'Шикоятҳои нав нест'), style: TextStyle(color: AppColors.muted))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = rows[i];
                final review = a['review'] as Map<String, dynamic>?;
                final body = (review?['body'] as String?)?.trim() ?? '';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Продавец: ${a['seller_name']}', 'Фурӯшанда: ${a['seller_name']}'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        if (review == null)
                          Text(tr('Отзыв уже удалён', 'Бознигарӣ аллакай нест шудааст'),
                              style: TextStyle(color: AppColors.muted))
                        else ...[
                          Text(tr('Отзыв от ${a['author_name']}, оценка ${review['rating']}/5',
                              'Бознигарӣ аз ${a['author_name']}, баҳо ${review['rating']}/5')),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('«$body»', style: TextStyle(color: AppColors.muted)),
                          ],
                        ],
                        const SizedBox(height: 8),
                        Text(tr('Причина обжалования:', 'Сабаби шикоят:'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(a['reason'] as String? ?? ''),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => _reject(a['id'] as String),
                              child: Text(tr('Отклонить', 'Рад кардан')),
                            ),
                            const Spacer(),
                            if (review != null)
                              FilledButton(
                                onPressed: () => _accept(a),
                                child: Text(tr('Одобрить и удалить отзыв', 'Қабул ва нест кардани бознигарӣ')),
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
