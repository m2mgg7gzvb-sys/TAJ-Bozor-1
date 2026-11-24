import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_listing_screen.dart';
import 'glass_widgets.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_detail_screen.dart';
import 'fallback_photo.dart';
import 'listing_utils.dart';
import 'listing_actions_sheet.dart';
import 'nav_state.dart';
import 'promote_sheet.dart';
import 'renew_sheet.dart';
import 'slide_up_in.dart';
import 'theme.dart';
import 'green_button.dart';

/// Статусы, при которых объявление переходит в раздел «Завершённые».
const _completedStatuses = {'sold', 'hidden', 'expired'};

/// Вкладка «Объявления»: для гостя — большой экран входа, для вошедшего — подача и свои объявления.
class MyListingsTab extends StatefulWidget {
  const MyListingsTab({super.key});

  @override
  State<MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends State<MyListingsTab> {
  late Future<List<Map<String, dynamic>>> _future;
  int _tab = 0; // 0 — активные, 1 — завершённые

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Вкладка «Объявления» — 2-я в нижней панели: при переходе на неё список обновляется.
    tabIndex.addListener(_onTabChanged);
  }

  Timer? _poll;

  @override
  void dispose() {
    tabIndex.removeListener(_onTabChanged);
    _poll?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (tabIndex.value == 2) _reload();
  }

  /// Пока есть объявления на проверке, статус перепроверяется каждые 30 секунд,
  /// чтобы не нужно было перезаходить в приложение.
  void _updatePoll(List<Map<String, dynamic>> rows) {
    final hasModeration = rows.any((e) => e['status'] == 'moderation');
    if (!hasModeration) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_poll == null || !_poll!.isActive) {
      _poll = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) _reload();
      });
    }
  }

  /// Все свои объявления, включая проданные и снятые: они нужны для раздела «Завершённые».
  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select('$listingSelect, status, admin_note, expires_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(rows);
    // Просмотры и избранное по каждому объявлению; без них список работает как раньше.
    try {
      final stats = await Supabase.instance.client.rpc('my_listing_stats') as List;
      final byId = <String, Map>{for (final s in stats) '${s['listing_id']}': s as Map};
      for (final item in list) {
        final st = byId['${item['id']}'];
        if (st != null) {
          item['views'] = st['views'];
          item['favs'] = st['favorites'];
        }
      }
    } catch (_) {}
    if (mounted) _updatePoll(list);
    return list;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (published == true) {
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление отправлено на проверку. Это занимает до 30 минут.')),
        );
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Отмечает объявление как проданное: оно уходит в «Завершённые» и пропадает из поиска.
  Future<void> _markSold(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отметить как продано?'),
        content: const Text('Объявление перейдёт в «Завершённые» и перестанет показываться в поиске.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          GreenButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Продано')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('listings')
          .update({'status': 'sold'}).eq('id', item['id'] as String);
      _reload();
      _snack('Отмечено как продано');
    } catch (_) {
      _snack('Не удалось изменить объявление');
    }
  }

  /// Продлевает истекшее объявление на 14 дней: оно снова идёт на проверку.
  Future<void> _renew(Map<String, dynamic> item) async {
    try {
      await Supabase.instance.client.from('listings').update({
        'status': 'moderation',
        'expires_at': DateTime.now().toUtc().add(const Duration(days: 14)).toIso8601String(),
        'expiry_notified_at': null,
      }).eq('id', item['id'] as String);
      _reload();
      _snack('Объявление продлено. Оно снова на проверке, это займёт до 30 минут.');
    } catch (_) {
      _snack('Не удалось продлить');
    }
  }

  /// Карточка своего объявления: фото слева, справа название, цена, место и счётчики.
  Widget _itemCard(Map<String, dynamic> item) {
    final status = item['status'] as String?;
    final note = (item['admin_note'] as String?)?.trim();
    final label = switch (status) {
      'moderation' => 'На проверке · до 30 минут',
      'blocked' => 'Заблокировано',
      'frozen' => 'Заморожено администратором',
      'expired' => 'Срок истёк',
      'sold' => 'Продано',
      'hidden' => 'Снято с публикации',
      _ => null,
    };
    final badgeColor = switch (status) {
      'blocked' => Colors.red.shade700,
      'frozen' => Colors.blueGrey.shade700,
      'expired' => Colors.grey.shade700,
      'sold' => AppColors.primary,
      'hidden' => Colors.grey.shade600,
      _ => Colors.orange.shade800,
    };
    final isActive = label == null;
    final topDays = topDaysLeft(item);
    final showTop = isActive && topDays > 0;
    final photo = photoUrl(item);
    final facts = [item['city'] as String?, ListingCard.factsOf(item)]
        .where((x) => x != null && x.trim().isNotEmpty)
        .join(' • ');
    final views = (item['views'] as num?)?.toInt() ?? 0;
    final favs = (item['favs'] as num?)?.toInt() ?? 0;
    final showNote = (status == 'blocked' || status == 'frozen') && note != null && note.isNotEmpty;

    Widget? tag;
    if (showTop) {
      tag = _pill(
        background: const Color(0xFFF5B301),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFF3B2A00)),
            const SizedBox(width: 4),
            Text(
              'TOP · $topDays дн.',
              style: const TextStyle(color: Color(0xFF3B2A00), fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    } else if (label != null) {
      tag = _pill(
        background: badgeColor,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    }

    Widget? daysTag;
    if (isActive) {
      final daysLeft = listingDaysLeft(item);
      daysTag = _pill(
        background: AppColors.surface.withValues(alpha: 0.92),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink),
            const SizedBox(width: 4),
            Text(
              daysLeft > 0 ? 'Осталось ${daysWord(daysLeft)}' : 'Срок истёк',
              style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: AppColors.deep.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 172,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 52,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          photo == null
                              ? FallbackPhoto(item: item)
                              : Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => FallbackPhoto(item: item),
                                ),
                          if (tag != null) Positioned(top: 10, left: 10, child: tag),
                          if (daysTag != null) Positioned(left: 10, bottom: 10, child: daysTag),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 48,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  (item['title'] as String?) ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                              ),
                              if (isActive)
                                Material(
                                  color: AppColors.surface,
                                  elevation: 2,
                                  shape: const CircleBorder(),
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Действия',
                                      icon: Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.ink),
                                      onPressed: () => showListingActions(
                                        context,
                                        title: (item['title'] as String?) ?? '',
                                        onTop: () => showPromoteSheet(
                                          context,
                                          listingId: item['id'] as String,
                                          title: (item['title'] as String?) ?? '',
                                        ),
                                        onSold: () => _markSold(item),
                                        onRenew: () => showRenewSheet(context, item: item, onDone: _reload),
                                        onEdit: () async {
                                          final saved = await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(builder: (_) => CreateListingScreen(listing: item)),
                                          );
                                          if (saved == true) _reload();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            priceText(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          if (facts.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    facts,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (showNote) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Причина: $note',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                          const Spacer(),
                          const SizedBox(height: 10),
                          Divider(height: 1, color: AppColors.line),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text('$views', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 12),
                              Container(width: 1, height: 14, color: AppColors.line),
                              const SizedBox(width: 12),
                              Icon(Icons.favorite, size: 18, color: AppColors.ruby),
                              const SizedBox(width: 4),
                              Text('$favs', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'expired')
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: GreenButton(
                    height: 36,
                    onPressed: () => _renew(item),
                    child: const Text('Продлить на 14 дней', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill({required Color background, required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: child,
      );

  /// Прозрачная шапка с заголовком по центру, как во вкладке «Избранное».
  PreferredSizeWidget _glassAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: Text(
        'Объявления',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
      ),
    );
  }

  Widget _emptyState(String title, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.post_add_rounded, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    if (!loggedIn) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _glassAppBar(),
        body: const GuestPrompt(
          icon: Icons.post_add_rounded,
          title: 'Войдите, чтобы публиковать объявления',
          text: 'Подайте объявление за несколько минут и находите покупателей по всему Таджикистану.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _glassAppBar(),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SlideUpIn(
            delay: const Duration(milliseconds: 150),
            child: SizedBox(
              height: 46,
              child: GreenButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Подать объявление',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          // При фоновом обновлении показываем прежние данные, без спиннера.
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(
              child: GreenButton(onPressed: _reload, child: const Text('Повторить')),
            );
          }
          final all = snapshot.data ?? [];
          final active = all.where((e) => !_completedStatuses.contains(e['status'])).toList();
          final completed = all.where((e) => _completedStatuses.contains(e['status'])).toList();
          final shown = _tab == 0 ? active : completed;

          final tabs = Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassTabs(
              labels: ['Активные (${active.length})', 'Завершённые (${completed.length})'],
              icons: const [Icons.directions_car_outlined, Icons.check_circle_outline_rounded],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          );

          if (shown.isEmpty) {
            return Column(
              children: [
                tabs,
                Expanded(
                  child: _tab == 0
                      ? _emptyState('Пока нет объявлений', 'Опубликуйте первое объявление — это займёт пару минут')
                      : _emptyState(
                          'Завершённых пока нет',
                          'Здесь появятся проданные, снятые и истёкшие объявления',
                        ),
                ),
              ],
            );
          }
          return Column(
            children: [
              tabs,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [for (final item in shown) _itemCard(item)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
