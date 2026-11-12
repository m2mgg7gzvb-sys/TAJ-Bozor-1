import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'listings_screen.dart';
import 'saved_searches_store.dart';
import 'theme.dart';

const _historyKey = 'search_history';

/// Экран поиска: поле ввода, «Отменить» и история запросов.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    SavedSearchesStore.load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _history = prefs.getStringList(_historyKey) ?? []);
    } catch (_) {
      // Историю можно не сохранять: поиск работает и без неё.
    }
  }

  Future<void> _saveHistory(List<String> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, items);
    } catch (_) {
      // Не критично: запрос всё равно выполнится.
    }
  }

  void _search(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    final updated = [q, ..._history.where((e) => e != q)].take(10).toList();
    setState(() => _history = updated);
    _saveHistory(updated);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingsScreen(initialQuery: q, title: q)),
    );
  }

  Future<void> _clear() async {
    setState(() => _history = []);
    await _saveHistory([]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Поиск по объявлениям',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF1F4F3),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отменить'),
                  ),
                ],
              ),
            ),
            if (_history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 4, 2),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Вы искали',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ),
                    TextButton(onPressed: _clear, child: const Text('Очистить')),
                  ],
                ),
              ),
            Expanded(
              child: ValueListenableBuilder<List<String>>(
                valueListenable: SavedSearchesStore.queries,
                builder: (context, saved, _) => ListView.separated(
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (_, i) {
                    final q = _history[i];
                    final isSaved = saved.contains(q);
                    return ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(q),
                      trailing: IconButton(
                        tooltip: isSaved ? 'Убрать из сохранённых' : 'Сохранить поиск',
                        icon: Icon(
                          isSaved ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isSaved ? const Color(0xFFF5A623) : AppColors.muted,
                        ),
                        onPressed: () => SavedSearchesStore.toggle(q),
                      ),
                      onTap: () => _search(q),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
