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
        .select(listingSelect)
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
    if (published == true) _reload();
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Подать объявление'),
            ),
          ),
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
                  return const Center(
                    child: Text(
                      'Вы ещё не публиковали объявления',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                return GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.66,
                  children: [for (final item in items) ListingCard(item: item)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
