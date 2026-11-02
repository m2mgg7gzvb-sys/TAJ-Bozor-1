import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'favorites_store.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_utils.dart';

/// Вкладка «Избранное»: объявления, которые пользователь сохранил.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    FavoritesStore.ids.addListener(_onChanged);
  }

  @override
  void dispose() {
    FavoritesStore.ids.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() => _future = _load());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    if (Supabase.instance.client.auth.currentSession == null) return [];
    final ids = FavoritesStore.ids.value.toList();
    if (ids.isEmpty) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .inFilter('id', ids)
        .eq('status', 'active');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: !loggedIn
          ? const GuestPrompt(
              icon: Icons.favorite_rounded,
              title: 'Войдите, чтобы открыть избранное',
              text: 'Сохраняйте понравившиеся объявления и возвращайтесь к ним в любой момент.',
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Повторить'),
                    ),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('В избранном пока пусто'));
                }
                return GridView.count(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.66,
                  children: [for (final item in items) ListingCard(item: item)],
                );
              },
            ),
    );
  }
}
