import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'favorites_store.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'listings_screen.dart';
import 'saved_searches_store.dart';

/// Вкладка «Избранное»: сохранённые объявления и сохранённые поиски.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  int _tab = 0; // 0 — объявления, 1 — сохранённые поиски

  @override
  void initState() {
    super.initState();
    _future = _load();
    SavedSearchesStore.load();
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

  Widget _listings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
    );
  }

  Widget _savedSearches() {
    return ValueListenableBuilder<List<SavedSearch>>(
      valueListenable: SavedSearchesStore.items,
      builder: (context, searches, child) {
        if (searches.isEmpty) {
          return const Center(
            child: Text('Звёздочкой в поиске можно сохранить запрос или фильтр'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: searches.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
          itemBuilder: (context, i) {
            final s = searches[i];
            return ListTile(
              leading: const Icon(Icons.saved_search_rounded),
              title: Text(s.title),
              trailing: IconButton(
                tooltip: 'Удалить из сохранённых',
                icon: const Icon(Icons.star_rounded, color: Color(0xFFF5A623)),
                onPressed: () => SavedSearchesStore.toggle(s),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingsScreen(
                    categoryId: s.categoryId,
                    subcategoryId: s.subcategoryId,
                    carFilter: s.carFilter,
                    initialQuery: s.query,
                    title: s.title,
                    savedFilters: s.filters,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Объявления')),
                      ButtonSegment(value: 1, label: Text('Сохранённые поиски')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                ),
                Expanded(child: _tab == 0 ? _listings() : _savedSearches()),
              ],
            ),
    );
  }
}
