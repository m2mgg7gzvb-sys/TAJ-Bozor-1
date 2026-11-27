import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'green_button.dart';
import 'lang_store.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'review_dialog.dart';
import 'theme.dart';

const _yellow = Color(0xFFF2B600);

/// Открывает объявление, на которое был оставлен отзыв.
Future<void> openReviewListing(BuildContext context, String listingId) async {
  final row = await Supabase.instance.client
      .from('listings')
      .select(listingSelect)
      .eq('id', listingId)
      .maybeSingle();
  if (!context.mounted) return;
  if (row == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(tr('Объявление недоступно', 'Эълон дастрас нест'))),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ListingDetailScreen(item: Map<String, dynamic>.from(row))),
  );
}

/// Экран отзывов о пользователе: сводка по звёздам, сортировка, тексты и кнопка «Написать отзыв».
class UserReviewsScreen extends StatefulWidget {
  const UserReviewsScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserReviewsScreen> createState() => _UserReviewsScreenState();
}

class _Review {
  _Review({
    required this.id,
    required this.authorId,
    required this.rating,
    required this.body,
    required this.createdAt,
    required this.listingId,
    required this.photos,
    required this.reply,
    required this.replyAt,
  });

  final String id;
  final String authorId;
  final int rating;
  final String? body;
  final DateTime createdAt;
  final String? listingId;
  final List<String> photos;
  String? reply;
  DateTime? replyAt;
  String authorName = '';
  String? listingTitle;
  String? appealStatus;
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
        .select('id, author_id, rating, body, created_at, listing_id, photos, reply, reply_at')
        .eq('reviewed_id', widget.userId)
        .order('created_at', ascending: false));
    final reviews = rows
        .map((r) => _Review(
              id: r['id'] as String,
              authorId: r['author_id'] as String,
              rating: (r['rating'] as num).toInt(),
              body: r['body'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              listingId: r['listing_id'] as String?,
              photos: List<String>.from((r['photos'] as List?) ?? const []),
              reply: r['reply'] as String?,
              replyAt: r['reply_at'] == null ? null : DateTime.parse(r['reply_at'] as String).toLocal(),
            ))
        .toList();
    final listingIds = reviews.map((r) => r.listingId).whereType<String>().toSet().toList();
    if (listingIds.isNotEmpty) {
      final ls = List<Map<String, dynamic>>.from(
          await _db.from('listings').select('id, title').inFilter('id', listingIds));
      final titles = {for (final l in ls) l['id'] as String: (l['title'] as String?) ?? ''};
      for (final r in reviews) {
        if (r.listingId != null) r.listingTitle = titles[r.listingId];
      }
    }
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
    if (_me.isNotEmpty && _me == widget.userId && reviews.isNotEmpty) {
      final ap = List<Map<String, dynamic>>.from(await _db
          .from('review_appeals')
          .select('review_id, status')
          .eq('seller_id', _me));
      final statuses = {for (final a in ap) a['review_id'] as String: a['status'] as String};
      for (final r in reviews) {
        r.appealStatus = statuses[r.id];
      }
    }
    return reviews;
  }

  /// Обжалование отзыва продавцом: причина, один раз на отзыв. Администратор рассматривает его.
  Future<void> _appeal(_Review r) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Обжаловать отзыв', 'Бознигариро шикоят кунед')),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: tr('Почему отзыв не соответствует действительности (от 10 символов)',
                'Чаро бознигарӣ ба воқеият мувофиқ нест (аз 10 аломат)'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Отмена', 'Бекор'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr('Отправить', 'Фиристодан')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;
    if (text.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Напишите причину от 10 символов', 'Сабаби аз 10 аломат нависед'))),
      );
      return;
    }
    try {
      await _db.from('review_appeals').insert({
        'review_id': r.id,
        'seller_id': _me,
        'reason': text,
      });
      if (mounted) setState(() => _future = _load());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Обжалование отправлено', 'Шикоят фиристода шуд'))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось отправить обжалование', 'Шикоят фиристода нашуд'))),
      );
    }
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

  void _showInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('О проверке отзывов', 'Дар бораи санҷиши бознигариҳо')),
        content: Text(tr(
          'Оставить отзыв можно только после переписки с продавцом по объявлению. Если отзыв нарушает правила, пожалуйтесь на него, и администрация проверит.',
          'Бознигарӣ танҳо пас аз мукотиба бо фурӯшанда дар бораи эълон гузошта мешавад. Агар бознигарӣ қоидаҳоро вайрон кунад, шикоят кунед, маъмурият санҷад.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Понятно', 'Фаҳмо'))),
        ],
      ),
    );
  }

  Future<void> _editReply(_Review r) async {
    final ctrl = TextEditingController(text: r.reply ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Ответ на отзыв', 'Ҷавоб ба бознигарӣ')),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(hintText: tr('Напишите ответ', 'Ҷавоб нависед')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Отмена', 'Бекор'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr('Сохранить', 'Захира')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;
    try {
      await _db
          .from('reviews')
          .update({'reply': text, 'reply_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', r.id);
      if (mounted) setState(() => _future = _load());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось сохранить ответ', 'Захира кардани ҷавоб муяссар нашуд'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _me.isNotEmpty && _me != widget.userId;
    final isOwner = _me.isNotEmpty && _me == widget.userId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(tr('Отзывы', 'Бознигариҳо')),
        actions: [
          IconButton(
            tooltip: tr('О проверке отзывов', 'Дар бораи санҷиш'),
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfo,
          ),
        ],
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
                    isOwner: isOwner,
                    onReply: () => _editReply(r),
                    onAppeal: () => _appeal(r),
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
  const _ReviewTile({
    required this.review,
    required this.expanded,
    required this.onToggle,
    required this.isOwner,
    required this.onReply,
    required this.onAppeal,
  });

  final _Review review;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isOwner;
  final VoidCallback onReply;
  final VoidCallback onAppeal;

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
          if (review.listingId != null) ...[
            GestureDetector(
              onTap: review.listingTitle == null ? null : () => openReviewListing(context, review.listingId!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sell_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (review.listingTitle ?? '').isNotEmpty
                            ? review.listingTitle!
                            : tr('Объявление удалено', 'Эълон нест карда шудааст'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: review.listingTitle == null ? AppColors.muted : AppColors.primary,
                        ),
                      ),
                    ),
                    if (review.listingTitle != null)
                      Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
                    if (review.listingId != null) ...[
                      const SizedBox(height: 2),
                      Text(tr('Сделка состоялась', 'Савдо анҷом ёфт'),
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
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
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final path in review.photos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _openPhoto(context, path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            Supabase.instance.client.storage.from('review-photos').getPublicUrl(path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Ответ продавца', 'Ҷавоби фурӯшанда'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(review.reply!),
                ],
              ),
            ),
          ],
          if (isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onReply,
                child: Text(review.reply == null || review.reply!.isEmpty
                    ? tr('Ответить', 'Ҷавоб додан')
                    : tr('Изменить ответ', 'Ҷавобро тағйир додан')),
              ),
            ),
          if (isOwner)
            Align(
              alignment: Alignment.centerRight,
              child: review.appealStatus == null
                  ? TextButton(
                      onPressed: onAppeal,
                      child: Text(tr('Обжаловать', 'Шикоят кардан')),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        switch (review.appealStatus) {
                          'accepted' => tr('Обжалование одобрено', 'Шикоят қабул шуд'),
                          'rejected' => tr('Обжалование отклонено', 'Шикоят рад шуд'),
                          _ => tr('Обжалование на рассмотрении', 'Шикоят баррасӣ мешавад'),
                        },
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

void _openPhoto(BuildContext context, String path) {
  final url = Supabase.instance.client.storage.from('review-photos').getPublicUrl(path);
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(8),
      child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
    ),
  );
}
