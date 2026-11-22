import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'green_button.dart';
import 'lang_store.dart';
import 'review_dialog.dart';
import 'theme.dart';

const _yellow = Color(0xFFF2B600);

/// Экран отзывов о пользователе: сводка по звёздам, сортировка, тексты и кнопка «Написать отзыв».
class UserReviewsScreen extends StatefulWidget {
  const UserReviewsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _Review {
  _Review({required this.authorId, required this.rating, required this.body, required this.createdAt});

  final String authorId;
  final int rating;
  final String? body;
  final DateTime createdAt;
  String authorName = '';
}

class _UserReviewsScreenState extends State<UserReviewsScreen> {
  final _db = Supabase.instance.client;
  late Future<List<_Review>> _future = _load();
  String _sort = 'new';
  final _expanded = <int>{};

  String get _me => _db.auth.currentUser?.id ?? '';

  Future<List<_Review>> _load() async {
    final rows = List<Map<String, dynamic>>.from(await _db
        .from('reviews')
        .select('author_id, rating, body, created_at')
        .eq('reviewed_id', widget.userId)
        .order('created_at', ascending: false));
    final reviews = rows
        .map((r) => _Review(
              authorId: r['author_id'] as String,
              rating: (r['rating'] as num).toInt(),
              body: r['body'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
            ))
        .toList();
    final ids = reviews.map((r) => r.authorId).toSet().toList();
    if (ids.isNotEmpty) {
      final profs = List<Map<String, dynamic>>.from(
          await _db.from('profiles').select('id, name').inFilter('id', ids));
      final names = {for (final p in profs) p['id'] as String: (p['name'] as String?) ?? ''};
      for (final r in reviews) {
        final n = names[r.authorId] ?? '';
        r.authorName = n.trim().isEmpty ? tr('Пользователь', 'Корбар') : n.trim();
      }
    }
    return reviews;
  }

  List<_Review> _sorted(List<_Review> list) {
    final l = [...list];
    switch (_sort) {
      case 'old':
        l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'pos':
        l.sort((a, b) => b.rating.compareTo(a.rating));
      case 'neg':
        l.sort((a, b) => a.rating.compareTo(b.rating));
      default:
        l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return l;
  }

  String get _sortLabel => switch (_sort) {
        'old' => tr('Сначала старые', 'Аввал кӯҳна'),
        'pos' => tr('Сначала положительные', 'Аввал мусбат'),
        'neg' => tr('Сначала отрицательные', 'Аввал манфӣ'),
        _ => tr('Сначала новые', 'Аввал нав'),
      };

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(tr('Сортировка отзывов', 'Сортикунии бознигариҳо'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final opt in const ['new', 'old', 'pos', 'neg'])
              ListTile(
                title: Text(switch (opt) {
                  'old' => tr('Сначала старые', 'Аввал кӯҳна'),
                  'pos' => tr('Сначала положительные', 'Аввал мусбат'),
                  'neg' => tr('Сначала отрицательные', 'Аввал манфӣ'),
                  _ => tr('Сначала новые', 'Аввал нав'),
                }),
                trailing: opt == _sort ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, opt),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _write() async {
    try {
      final id = await findOrCreateConversation(kind: 'listing', sellerId: widget.userId);
      if (!mounted) return;
      final sent = await showReviewSheet(context, sellerId: widget.userId, conversationId: id);
      if (sent && mounted) setState(() => _future = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть переписку', 'Кушодани мактубот муяссар нашуд'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _me.isNotEmpty && _me != widget.userId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(tr('Отзывы', 'Бознигариҳо')),
      ),
      bottomNavigationBar: canWrite
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GreenButton(
                  onPressed: _write,
                  child: Text(tr('Написать отзыв', 'Бознигарӣ навиштан')),
                ),
              ),
            )
          : null,
      body: FutureBuilder<List<_Review>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(tr('Не удалось загрузить отзывы', 'Бор кардани бознигариҳо муяссар нашуд')));
          }
          final reviews = snap.data ?? const <_Review>[];
          final total = reviews.length;
          final avg = total == 0 ? 0.0 : reviews.fold<int>(0, (s, r) => s + r.rating) / total;
          final counts = {for (var s = 1; s <= 5; s++) s: reviews.where((r) => r.rating == s).length};
          final list = _sorted(reviews);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(avg.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 16,
                                color: i <= avg.round() ? _yellow : AppColors.muted,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(tr('$total отзывов', '$total бознигарӣ'),
                            style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          for (var s = 5; s >= 1; s--)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text('$s', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: total == 0 ? 0 : counts[s]! / total,
                                        minHeight: 6,
                                        color: _yellow,
                                        backgroundColor: AppColors.muted.withValues(alpha: 0.18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 24,
                                    child: Text('${counts[s]}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: total == 0 ? null : _pickSort,
                  icon: const Icon(Icons.swap_vert_rounded, size: 18),
                  label: Text(_sortLabel),
                ),
              ),
              const SizedBox(height: 12),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(tr('Отзывов пока нет', 'Бознигарӣ ҳанӯз нест'),
                        style: TextStyle(color: AppColors.muted)),
                  ),
                )
              else
                for (final r in list) ...[
                  _ReviewTile(
                    review: r,
                    expanded: _expanded.contains(identityHashCode(r)),
                    onToggle: () => setState(() {
                      final key = identityHashCode(r);
                      _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key);
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.expanded, required this.onToggle});

  final _Review review;
  final bool expanded;
  final VoidCallback onToggle;

  String get _date {
    final d = review.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final body = review.body?.trim() ?? '';
    final long = body.length > 140;
    final initial = review.authorName.isEmpty ? '?' : review.authorName.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_date, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: i <= review.rating ? _yellow : AppColors.muted,
                    ),
                ],
              ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              body,
              maxLines: expanded || !long ? null : 3,
              overflow: expanded || !long ? null : TextOverflow.ellipsis,
            ),
            if (long)
              GestureDetector(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    expanded ? tr('Свернуть', 'Пинҳон') : tr('Показать целиком', 'Пурра нишон додан'),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
