import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_listing_screen.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Вкладка «Объявления»: для гостя — большой экран входа, для вошедшего — подача и свои объявления.
class MyListingsTab extends StatefulWidget {
  const MyListingsTab({super.key});

  @override
  State<MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends State<MyListingsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select('$listingSelect, status, admin_note')
        .eq('user_id', user.id)
        .neq('status', 'hidden')
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

  /// Продлевает истекшее объявление на 14 дней: оно снова идёт на проверку.
  Future<void> _renew(Map<String, dynamic> item) async {
    try {
      await Supabase.instance.client.from('listings').update({
        'status': 'moderation',
        'expires_at': DateTime.now().toUtc().add(const Duration(days: 14)).toIso8601String(),
      }).eq('id', item['id'] as String);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление продлено. Оно снова на проверке, это займёт до 30 минут.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось продлить')));
      }
    }
  }

  /// Карточка со статусом: на проверке, заблокировано, заморожено или истекло.
  /// Для заблокированного и замороженного показывается причина от администратора.
  Widget _itemCard(Map<String, dynamic> item) {
    final status = item['status'] as String?;
    final note = (item['admin_note'] as String?)?.trim();
    final label = switch (status) {
      'moderation' => 'На проверке · до 30 минут',
      'blocked' => 'Заблокировано',
      'frozen' => 'Заморожено администратором',
      'expired' => 'Срок истёк',
      _ => null,
    };
    final card = ListingCard(item: item);
    if (label == null) return card;
    final badgeColor = switch (status) {
      'blocked' => Colors.red.shade700,
      'frozen' => Colors.blueGrey.shade700,
      'expired' => Colors.grey.shade700,
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
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.post_add_rounded, size: 64, color: AppColors.muted),
                          SizedBox(height: 16),
                          Text(
                            'Пока нет объявлений',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Опубликуйте первое объявление — это займёт пару минут',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.66,
                  children: [for (final item in items) _itemCard(item)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
