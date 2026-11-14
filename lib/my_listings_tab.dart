import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_listing_screen.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'listing_actions_sheet.dart';
import 'promote_sheet.dart';
import 'theme.dart';

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
  }

  /// Все свои объявления, включая проданные и снятые: они нужны для раздела «Завершённые».
  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select('$listingSelect, status, admin_note')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
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
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Продано')),
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

  /// Карточка со статусом. Активные — с кнопками «Продано» и «В топ»;
  /// на проверке, заблокированные, замороженные, проданные, снятые и истёкшие — с меткой.
  /// Для заблокированного и замороженного показывается причина от администратора.
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
    final card = ListingCard(item: item);
    if (label == null) {
      // Активное объявление: действия в меню в левом верхнем углу, карточка не меняется.
      return Stack(
        children: [
          card,
          Positioned(
            top: 6,
            left: 6,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Действия',
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.ink),
                onPressed: () => showListingActions(
                  context,
                  title: (item['title'] as String?) ?? '',
                  onTop: () => showPromoteSheet(context, title: (item['title'] as String?) ?? ''),
                  onSold: () => _markSold(item),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final badgeColor = switch (status) {
      'blocked' => Colors.red.shade700,
      'frozen' => Colors.blueGrey.shade700,
      'expired' => Colors.grey.shade700,
      'sold' => AppColors.primary,
      'hidden' => Colors.grey.shade600,
      _ => Colors.orange.shade800,
    };
    final showNote = (status == 'blocked' || status == 'frozen') && note != null && note.isNotEmpty;
    return Stack(
      children: [
        card,
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (status == 'expired')
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
              onPressed: () => _renew(item),
              child: const Text('Продлить на 14 дней', style: TextStyle(fontSize: 13)),
            ),
          ),
        if (showNote)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Text(
                'Причина: $note',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyState(String title, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.post_add_rounded, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
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
        appBar: AppBar(title: const Text('Объявления')),
        body: const GuestPrompt(
          icon: Icons.post_add_rounded,
          title: 'Войдите, чтобы публиковать объявления',
          text: 'Подайте объявление за несколько минут и находите покупателей по всему Таджикистану.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Объявления')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Подать объявление',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton(onPressed: _reload, child: const Text('Повторить')),
            );
          }
          final all = snapshot.data ?? [];
          final active = all.where((e) => !_completedStatuses.contains(e['status'])).toList();
          final completed = all.where((e) => _completedStatuses.contains(e['status'])).toList();
          final shown = _tab == 0 ? active : completed;

          final tabs = Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Text('Активные (${active.length})')),
                ButtonSegment(value: 1, label: Text('Завершённые (${completed.length})')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
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
                child: GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.66,
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
