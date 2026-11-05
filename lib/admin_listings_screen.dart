import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Все объявления для админов: фильтр по статусу, поиск по названию и действия
/// (заморозить, заблокировать, удалить, вернуть в активные).
class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

const _filters = <String, String>{
  'active': 'Активные',
  'frozen': 'Заморожены',
  'blocked': 'Заблокированы',
  'hidden': 'Скрытые',
};

class _AdminListingsScreenState extends State<AdminListingsScreen> {
  final _db = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  String _status = 'active';
  late Future<List<Map<String, dynamic>>> _future = _load();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db
        .from('listings')
        .select('$listingSelect, status')
        .eq('status', _status)
        .order('created_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _future = _load());

  void _setFilter(String status) {
    _status = status;
    _reload();
  }

  Future<void> _set(String id, String status, String message) async {
    try {
      await _db.from('listings').update({'status': status}).eq('id', id);
      _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить изменение')),
        );
      }
    }
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(title: const Text('Все объявления')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                for (final e in _filters.entries) ...[
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => _setFilter(e.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return ListView(children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Не удалось загрузить объявления',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    ]);
                  }
                  final all = snap.data ?? const <Map<String, dynamic>>[];
                  final items = query.isEmpty
                      ? all
                      : all
                          .where((i) => ((i['title'] as String?) ?? '').toLowerCase().contains(query))
                          .toList();
                  if (items.isEmpty) {
                    return ListView(children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Ничего не найдено',
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    ]);
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final item in items) ...[
                        _AdminTile(
                          item: item,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
                          ),
                          onFreeze: () => _set(item['id'] as String, 'frozen', 'Объявление заморожено'),
                          onUnfreeze: () => _set(item['id'] as String, 'active', 'Объявление разморожено'),
                          onRestore: () => _set(item['id'] as String, 'active', 'Объявление активно'),
                          onBlock: () async {
                            if (await _confirm('Заблокировать объявление?')) {
                              _set(item['id'] as String, 'blocked', 'Объявление заблокировано');
                            }
                          },
                          onDelete: () async {
                            if (await _confirm('Удалить объявление? Его не будет видно никому.')) {
                              _set(item['id'] as String, 'hidden', 'Объявление удалено');
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.item,
    required this.onOpen,
    required this.onFreeze,
    required this.onUnfreeze,
    required this.onRestore,
    required this.onBlock,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  final VoidCallback onFreeze;
  final VoidCallback onUnfreeze;
  final VoidCallback onRestore;
  final VoidCallback onBlock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] as String?) ?? '';
    final photo = photoUrl(item);
    final city = (item['city'] as String?) ?? '';

    final List<Widget> actions = switch (status) {
      'active' => [
          OutlinedButton(onPressed: onFreeze, child: const Text('Заморозить')),
          OutlinedButton(onPressed: onBlock, child: const Text('Блокировать')),
        ],
      'frozen' => [
          FilledButton(onPressed: onUnfreeze, child: const Text('Разморозить')),
          OutlinedButton(onPressed: onBlock, child: const Text('Блокировать')),
        ],
      'blocked' => [
          FilledButton(onPressed: onRestore, child: const Text('Разблокировать')),
        ],
      'hidden' => [
          FilledButton(onPressed: onRestore, child: const Text('Вернуть')),
        ],
      _ => <Widget>[],
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: photo == null
                        ? Container(color: AppColors.mint)
                        : Image.network(photo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['title'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(priceText(item),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                      if (city.isNotEmpty)
                        Text(city, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...actions,
              TextButton(
                onPressed: onDelete,
                child: Text('Удалить', style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
