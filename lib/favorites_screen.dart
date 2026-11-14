import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'compare_screen.dart';
import 'fallback_photo.dart';
import 'favorites_store.dart';
import 'guest_prompt.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'listings_screen.dart';
import 'saved_searches_store.dart';
import 'glass_widgets.dart';
import 'theme.dart';

/// Вкладка «Избранное»: сохранённые объявления и сохранённые поиски.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const _maxCompare = 3;

  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _loaded = [];
  int _tab = 0; // 0 — объявления, 1 — сохранённые поиски
  bool _compareMode = false;
  final Set<String> _picked = {};
  final Map<String, String> _notes = {}; // заметки к избранному: id объявления → текст

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
    final items = List<Map<String, dynamic>>.from(rows);
    _loaded = items;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        final notes = await Supabase.instance.client
            .from('favorite_notes')
            .select('listing_id, note')
            .eq('user_id', uid)
            .inFilter('listing_id', ids);
        _notes
          ..clear()
          ..addAll({for (final n in notes) n['listing_id'] as String: (n['note'] as String?) ?? ''});
      } catch (_) {
        // Заметки необязательны: без них список всё равно открывается.
      }
    }
    return items;
  }

  /// Открывает окно заметки к объявлению. Пустой текст удаляет заметку.
  Future<void> _editNote(String id) async {
    final current = _notes[id] ?? '';
    final ctrl = TextEditingController(text: current);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: 'Заметка к объявлению',
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 500,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Например: позвонить после 18:00',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (text == null || text == current) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final db = Supabase.instance.client.from('favorite_notes');
      if (text.isEmpty) {
        await db.delete().eq('user_id', uid).eq('listing_id', id);
        _notes.remove(id);
      } else {
        await db.upsert({
          'user_id': uid,
          'listing_id': id,
          'note': text,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id,listing_id');
        _notes[id] = text;
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить заметку')),
        );
      }
    }
  }

  /// Карточка с кнопкой заметки в левом верхнем углу.
  Widget _withNote(Map<String, dynamic> item) {
    final id = item['id'] as String;
    final hasNote = (_notes[id] ?? '').trim().isNotEmpty;
    return Stack(
      children: [
        GlowCard(child: ListingCard(item: item)),
        Positioned(
          top: 6,
          left: 6,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: hasNote ? 'Заметка: ${_notes[id]}' : 'Добавить заметку',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                hasNote ? Icons.sticky_note_2_rounded : Icons.edit_note_rounded,
                size: 20,
                color: hasNote ? AppColors.primary : AppColors.muted,
              ),
              onPressed: () => _editNote(id),
            ),
          ),
        ),
      ],
    );
  }

  void _toggleCompare() {
    setState(() {
      _compareMode = !_compareMode;
      _picked.clear();
    });
  }

  void _togglePick(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
      } else if (_picked.length < _maxCompare) {
        _picked.add(id);
      }
    });
  }

  void _openCompare() {
    final chosen = _loaded.where((it) => _picked.contains(it['id'] as String)).toList();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CompareScreen(items: chosen)),
    );
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
        if (_compareMode) return _selectList(items);
        return GridView.count(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.66,
          children: [for (final item in items) _withNote(item)],
        );
      },
    );
  }

  /// Режим сравнения: список с выбором до трёх объявлений.
  Widget _selectList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final it = items[i];
        final id = it['id'] as String;
        final on = _picked.contains(id);
        final photo = photoUrl(it);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: photo == null
                  ? FallbackPhoto(item: it)
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => FallbackPhoto(item: it),
                    ),
            ),
          ),
          title: Text(
            it['title'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(priceText(it)),
          trailing: Icon(
            on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: on ? AppColors.primary : AppColors.muted,
          ),
          onTap: () => _togglePick(id),
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
    final showCompare = loggedIn && _tab == 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Избранное',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.deep),
        ),
        actions: [
          if (showCompare)
            TextButton(
              onPressed: _toggleCompare,
              child: Text(_compareMode ? 'Отмена' : 'Сравнить'),
            ),
        ],
      ),
      bottomNavigationBar: _compareMode && showCompare
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _picked.length >= 2 ? _openCompare : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: Text('Сравнить (${_picked.length} из $_maxCompare)'),
                  ),
                ),
              ),
            )
          : null,
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
                  child: GlassTabs(
                    labels: const ['Объявления', 'Сохранённые поиски'],
                    selected: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                Expanded(child: _tab == 0 ? _listings() : _savedSearches()),
              ],
            ),
    );
  }
}
