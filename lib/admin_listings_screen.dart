import 'lang_store.dart';
import 'package:flutter/material.dart';

import 'create_listing_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'admin_log.dart';
import 'admin_daily_stats.dart';
import 'confirm_delete.dart';
import 'glass_widgets.dart';
import 'theme.dart';
import 'green_button.dart';

/// Все объявления для админов: фильтр по статусу, поиск по названию и действия
/// (заморозить, заблокировать, удалить, вернуть в активные).
class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

final _filters = <String, String>{
  'active': tr('Активные', 'Фаъол'),
  'frozen': tr('Заморожены', 'Музд шудаанд'),
  'blocked': tr('Заблокированы', 'Маҳдуд шудаанд'),
  'hidden': tr('Скрытые', 'Пинҳон'),
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
    _selected.clear();
    _reload();
  }

  /// Выбранные объявления для массовых действий (долгое нажатие на карточку).
  final _selected = <String>{};
  bool get _selecting => _selected.isNotEmpty;

  void _toggleSel(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  /// Применяет одно действие ко всем выбранным объявлениям по очереди.
  Future<void> _bulk(String status, String message, String action, {bool askNote = false}) async {
    String? note;
    if (askNote) {
      note = await askReason(context, tr('Причина для выбранных объявлений', 'Сабаб барои эълонҳои интихобшуда'));
      if (note == null) return;
    }
    final ids = _selected.toList();
    var done = 0;
    for (final id in ids) {
      try {
        await adminSetStatus(
          listingId: id,
          status: status,
          action: action,
          note: (note == null || note.isEmpty) ? null : note,
        );
        done++;
      } catch (_) {
        // Ошибку одного объявления пропускаем, остальные продолжаем.
      }
    }
    setState(_selected.clear);
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('$message: $done из ${ids.length}', '$message: $done аз ${ids.length}'))),
      );
    }
  }

  Future<void> _set(String id, String status, String message,
      {required String action, String? note}) async {
    try {
      await adminSetStatus(listingId: id, status: status, action: action, note: note);
      _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Не удалось сохранить изменение', 'Захира кардани тағйирот муяссар нашуд'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
        title: _selecting ? Text(tr('Выбрано: ${_selected.length}', 'Интихоб: ${_selected.length}')) : Text(tr('Все объявления', 'Ҳамаи эълонҳо')),
        leading: _selecting
            ? IconButton(
                tooltip: tr('Отменить выбор', 'Бекор кардани интихоб'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(_selected.clear),
              )
            : null,
        actions: _selecting
            ? [
                IconButton(
                  tooltip: tr('Активировать', 'Фаъол кардан'),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  onPressed: () => _bulk('active', tr('Активировано', 'Фаъол карда шуд'), 'restore'),
                ),
                IconButton(
                  tooltip: tr('Заморозить', 'Музд кардан'),
                  icon: const Icon(Icons.ac_unit_rounded),
                  onPressed: () => _bulk('frozen', tr('Заморожено', 'Музд шудааст'), 'freeze', askNote: true),
                ),
                IconButton(
                  tooltip: tr('Заблокировать', 'Маҳдуд кардан'),
                  icon: const Icon(Icons.block_rounded),
                  onPressed: () => _bulk('blocked', tr('Заблокировано', 'Маҳдуд шудааст'), 'block', askNote: true),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          const AdminDailyStats(),
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
                hintText: tr('Поиск по названию', 'Ҷустуҷӯ аз рӯи ном'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surface,
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
                    return ListView(children: [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(tr('Не удалось загрузить объявления', 'Бор кардани эълонҳо муяссар нашуд'),
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
                    return ListView(children: [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(tr('Ничего не найдено', 'Чизе ёфт нашуд'),
                            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                      ),
                    ]);
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final item in items) ...[
                        GestureDetector(
                          onLongPress: () => _toggleSel(item['id'] as String),
                          onTap: _selecting ? () => _toggleSel(item['id'] as String) : null,
                          child: Container(
                            decoration: _selected.contains(item['id'])
                                ? BoxDecoration(
                                    border: Border.all(color: AppColors.primary, width: 2),
                                    borderRadius: BorderRadius.circular(18),
                                  )
                                : null,
                            child: AbsorbPointer(
                              absorbing: _selecting,
                              child: _AdminTile(
                          item: item,
                          onOpen: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
                          ),
                          onFreeze: () async {
                            final note = await askReason(context, tr('Заморозить объявление?', 'Эълонро музд кунем?'));
                            if (note == null) return;
                            _set(item['id'] as String, 'frozen', tr('Объявление заморожено', 'Эълон музд карда шуд'),
                                action: 'freeze', note: note.isEmpty ? null : note);
                          },
                          onEdit: () async {
                            final saved = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => CreateListingScreen(listing: item, adminEdit: true),
                              ),
                            );
                            if (saved == true) _reload();
                          },
                          onUnfreeze: () => _set(item['id'] as String, 'active', tr('Объявление разморожено', 'Эълон аз музд баромад'),
                              action: 'unfreeze'),
                          onRestore: () => _set(item['id'] as String, 'active', tr('Объявление активно', 'Эълон фаъол аст'),
                              action: 'restore'),
                          onBlock: () async {
                            final note = await askReason(context, tr('Заблокировать объявление?', 'Эълонро маҳдуд кунем?'));
                            if (note == null) return;
                            _set(item['id'] as String, 'blocked', tr('Объявление заблокировано', 'Эълон маҳдуд карда шуд'),
                                action: 'block', note: note.isEmpty ? null : note);
                          },
                          onDelete: () async {
                            if (await confirmDeleteByTyping(context)) {
                              _set(item['id'] as String, 'hidden', tr('Объявление удалено', 'Эълон нест карда шуд'), action: 'delete');
                            }
                          },
                              ),
                            ),
                          ),
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
    required this.onEdit,
  });

  final VoidCallback onEdit;

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

    final List<Widget> statusActions = switch (status) {
      'active' => [
          OutlinedButton(onPressed: onFreeze, child: Text(tr('Заморозить', 'Музд кардан'))),
          OutlinedButton(onPressed: onBlock, child: Text(tr('Блокировать', 'Маҳдуд кардан'))),
        ],
      'frozen' => [
          GreenButton(onPressed: onUnfreeze, child: Text(tr('Разморозить', 'Аз музд баровардан'))),
          OutlinedButton(onPressed: onBlock, child: Text(tr('Блокировать', 'Маҳдуд кардан'))),
        ],
      'blocked' => [
          GreenButton(onPressed: onRestore, child: Text(tr('Разблокировать', 'Маҳдудиятро бардоштан'))),
        ],
      'hidden' => [
          GreenButton(onPressed: onRestore, child: Text(tr('Вернуть', 'Баргардонидан'))),
        ],
      _ => <Widget>[],
    };
    final actions = <Widget>[
      OutlinedButton(onPressed: onEdit, child: Text(tr('Изменить', 'Таҳрир'))),
      ...statusActions,
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: glowDecoration(radius: 20),
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
                        Text(city, style: TextStyle(color: AppColors.muted, fontSize: 13)),
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
                child: Text(tr('Удалить', 'Нест кардан'), style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
