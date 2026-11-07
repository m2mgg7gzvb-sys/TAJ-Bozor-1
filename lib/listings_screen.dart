import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'car_catalog.dart';
import 'city_store.dart';
import 'lang_store.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'search_terms.dart';
import 'theme.dart';

/// Лента объявлений. Может быть отфильтрована по категории и по поисковой строке.
/// Для категории «Авто» (carFilter) сверху показывается блок «Найти автомобиль».
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({
    super.key,
    this.categoryId,
    this.title = 'Объявления',
    this.initialQuery,
    this.carFilter = false,
  });

  final int? categoryId;
  final String? initialQuery;
  final String title;
  final bool carFilter;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _searchCtrl = TextEditingController();
  String? _brand;
  String? _model;
  String? _generation;
  final _priceMinCtrl = TextEditingController();
  final _priceMaxCtrl = TextEditingController();
  final _yearMinCtrl = TextEditingController();
  final _yearMaxCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  int? _count;

  /// Подкатегории выбранной категории и выбранная плитка.
  late Future<List<Map<String, dynamic>>> _subcats = _loadSubcats();
  int? _subcatId;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery ?? '';
    _future = _load();
    selectedCity.addListener(_reload);
  }

  @override
  void dispose() {
    selectedCity.removeListener(_reload);
    _searchCtrl.dispose();
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    _yearMinCtrl.dispose();
    _yearMaxCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    var query = Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active');
    if (widget.categoryId != null) {
      query = query.eq('category_id', widget.categoryId!);
    }
    if (_subcatId != null) {
      query = query.eq('subcategory_id', _subcatId!);
    }
    final city = selectedCity.value;
    if (city != null) {
      query = query.eq('city', city);
    }
    final variants = searchVariants(_searchCtrl.text);
    final rank = <String, int>{};
    if (variants.isNotEmpty) {
      // Поиск в базе с учётом опечаток и вариантов написания («бмв» → BMW, «toyta» → Toyota).
      final hits = await Supabase.instance.client
          .rpc('search_listing_ids', params: {'terms': variants}) as List;
      final ids = hits.map((h) => h['id'] as String).toList();
      if (ids.isEmpty) {
        if (mounted) setState(() => _count = 0);
        return [];
      }
      for (var i = 0; i < ids.length; i++) {
        rank[ids[i]] = i;
      }
      query = query.inFilter('id', ids);
    }
    if (widget.carFilter) {
      if (_brand != null) query = query.eq('details->>brand', _brand!);
      if (_model != null) query = query.eq('details->>model', _model!);
      if (_generation != null) query = query.eq('details->>generation', _generation!);
      final priceMin = num.tryParse(_priceMinCtrl.text.trim());
      if (priceMin != null) query = query.gte('price', priceMin);
      final priceMax = num.tryParse(_priceMaxCtrl.text.trim());
      if (priceMax != null) query = query.lte('price', priceMax);
      final yearMin = int.tryParse(_yearMinCtrl.text.trim());
      if (yearMin != null) query = query.gte('details->>year', '$yearMin');
      final yearMax = int.tryParse(_yearMaxCtrl.text.trim());
      if (yearMax != null) query = query.lte('details->>year', '$yearMax');
    }
    final rows = await query.order('created_at', ascending: false).limit(100);
    final items = List<Map<String, dynamic>>.from(rows);
    if (rank.isNotEmpty) {
      // При поиске сначала самые похожие на запрос.
      items.sort((a, b) => (rank[a['id']] ?? 1 << 30).compareTo(rank[b['id']] ?? 1 << 30));
    }
    if (mounted) setState(() => _count = items.length);
    return items;
  }

  void _reload() => setState(() => _future = _load());

  Future<List<Map<String, dynamic>>> _loadSubcats() async {
    if (widget.categoryId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('subcategories')
          .select('id, name_ru')
          .eq('category_id', widget.categoryId!)
          .order('sort');
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  IconData _subcatIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('телефон')) return Icons.smartphone_rounded;
    if (n.contains('аудио')) return Icons.headphones_rounded;
    if (n.contains('игр')) return Icons.sports_esports_rounded;
    if (n.contains('ноутбук')) return Icons.laptop_rounded;
    if (n.contains('настольн')) return Icons.desktop_windows_rounded;
    if (n.contains('компьютер')) return Icons.memory_rounded;
    if (n.contains('фото')) return Icons.photo_camera_rounded;
    if (n.contains('планшет')) return Icons.tablet_mac_rounded;
    if (n.contains('оргтехник')) return Icons.print_rounded;
    if (n.contains('новые авто')) return Icons.new_releases_rounded;
    if (n.contains('селект')) return Icons.star_rounded;
    if (n.contains('легков')) return Icons.directions_car_rounded;
    if (n.contains('грузов')) return Icons.local_shipping_rounded;
    if (n.contains('мото')) return Icons.two_wheeler_rounded;
    if (n.contains('аренда авто')) return Icons.car_rental_rounded;
    if (n.contains('аренда техники')) return Icons.construction_rounded;
    if (n.contains('запчаст')) return Icons.build_rounded;
    return Icons.category_rounded;
  }

  Widget _subcatRow() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _subcats,
      builder: (context, snap) {
        final subs = snap.data ?? const <Map<String, dynamic>>[];
        if (subs.isEmpty) return const SizedBox.shrink();
        final rows = _tileRows(subs);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        Expanded(child: _subcatTile(row[i], wide: row.length == 2)),
                        if (i < row.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Ряды плиток: сначала 2 широкие, потом 3 узкие, и так по кругу (как на Авито).
  List<List<Map<String, dynamic>>> _tileRows(List<Map<String, dynamic>> subs) {
    final rows = <List<Map<String, dynamic>>>[];
    var i = 0;
    var wide = true;
    while (i < subs.length) {
      final n = wide ? 2 : 3;
      final end = (i + n) > subs.length ? subs.length : i + n;
      rows.add(subs.sublist(i, end));
      i = end;
      wide = !wide;
    }
    return rows;
  }

  Widget _subcatTile(Map<String, dynamic> s, {required bool wide}) {
    final id = s['id'] as int;
    final name = s['name_ru'] as String;
    final selected = _subcatId == id;
    return Material(
      color: selected ? AppColors.primary : const Color(0xFFF2F4F3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() => _subcatId = selected ? null : id);
          _reload();
        },
        child: SizedBox(
          height: 84,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: selected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Icon(
                  _subcatIcon(name),
                  size: wide ? 34 : 30,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Верхний баннер категории: логотип и название TAJ Bozor.
  Widget _topBanner() {
    return Container(
      width: double.infinity,
      height: 240,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/logo.svg', width: 84, height: 84),
          const SizedBox(height: 14),
          const Text(
            'TAJ Bozor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _newCarousel(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            tr('Новые объявления', 'Эълонҳои нав'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: 165, child: ListingCard(item: items[i])),
          ),
        ),
      ],
    );
  }

  /// Выбор из списка в нижнем окне. Пустая строка значит «любой» (все).
  Future<String?> _pickFromList({
    required String title,
    required List<String> items,
    required String anyLabel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(title: Text(anyLabel), onTap: () => Navigator.pop(ctx, '')),
                    for (final i in items)
                      ListTile(title: Text(i), onTap: () => Navigator.pop(ctx, i)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Диапазон «от» и «до» (цена или год) в нижнем окне.
  Future<void> _rangeSheet({
    required String title,
    required TextEditingController from,
    required TextEditingController to,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: from,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'от'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: to,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'до'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carFilterBlock() {
    Widget tile(String label, String? value, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: value == null ? Colors.black54 : Colors.black87),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.black54),
            ],
          ),
        ),
      );
    }

    String? rangeText(TextEditingController a, TextEditingController b) {
      final from = a.text.trim();
      final to = b.text.trim();
      if (from.isEmpty && to.isEmpty) return null;
      if (from.isNotEmpty && to.isNotEmpty) return 'от $from до $to';
      return from.isNotEmpty ? 'от $from' : 'до $to';
    }

    Future<void> pickBrandAndModel() async {
      final brand = await _pickFromList(
        title: 'Марка',
        items: carCatalog.keys.toList(),
        anyLabel: 'Все марки',
      );
      if (brand == null) return;
      setState(() {
        _brand = brand.isEmpty ? null : brand;
        _model = null;
        _generation = null;
      });
      if (brand.isEmpty) return;
      // Сразу после выбора марки открываем список моделей.
      final model = await _pickFromList(
        title: 'Модель',
        items: carCatalog[brand]?.keys.toList() ?? <String>[],
        anyLabel: 'Все модели',
      );
      if (model == null) return;
      setState(() {
        _model = model.isEmpty ? null : model;
        _generation = null;
      });
    }

    final generations = (_brand != null && _model != null)
        ? (carCatalog[_brand]?[_model] ?? <String>[])
        : <String>[];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Найти автомобиль', 'Ёфтани мошин'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          // Ряд 1: марка и модель (модель появляется после выбора марки)
          Row(
            children: [
              Expanded(
                child: tile('Все марки', _brand, pickBrandAndModel),
              ),
              if (_brand != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: tile('Все модели', _model, () async {
                    final model = await _pickFromList(
                      title: 'Модель',
                      items: carCatalog[_brand]?.keys.toList() ?? <String>[],
                      anyLabel: 'Все модели',
                    );
                    if (model == null) return;
                    setState(() {
                      _model = model.isEmpty ? null : model;
                      _generation = null;
                    });
                  }),
                ),
              ],
            ],
          ),
          if (generations.isNotEmpty) ...[
            const SizedBox(height: 8),
            tile('Все поколения', _generation, () async {
              final gen = await _pickFromList(
                title: 'Поколение',
                items: generations,
                anyLabel: 'Все поколения',
              );
              if (gen == null) return;
              setState(() => _generation = gen.isEmpty ? null : gen);
            }),
            if (_generation != null) carGenerationPhoto(_brand!, _model!, _generation!),
          ],
          const SizedBox(height: 8),
          // Ряд 2: цена и год, каждое открывается нижним окном «от / до»
          Row(
            children: [
              Expanded(
                child: tile(
                  'Цена',
                  rangeText(_priceMinCtrl, _priceMaxCtrl),
                  () => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: tile(
                  'Год',
                  rangeText(_yearMinCtrl, _yearMaxCtrl),
                  () => _rangeSheet(title: 'Год выпуска', from: _yearMinCtrl, to: _yearMaxCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _reload,
            child: Text(_count == null ? 'Показать объявления' : 'Показать $_count объявлений'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
          _subcatRow(),
          if (widget.carFilter) _carFilterBlock(),
          if (widget.categoryId != null) _topBanner(),
          if (widget.categoryId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _reload(),
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
          FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Не удалось загрузить объявления'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _reload, child: const Text('Повторить')),
                      ],
                    ),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(child: Text(tr('Ничего не найдено', 'Ҳеҷ чиз ёфт нашуд')));
                }
                return Column(
                  children: [
                    if (items.length > 2) _newCarousel(items.take(10).toList()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.66,
                        children: [for (final item in items) ListingCard(item: item)],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
