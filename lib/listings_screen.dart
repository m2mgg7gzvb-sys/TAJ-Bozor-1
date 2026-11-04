import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'car_catalog.dart';
import 'city_store.dart';
import 'lang_store.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
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
  String? _yearMin;
  final _priceMinCtrl = TextEditingController();
  final _priceMaxCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  int? _count;

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
    final city = selectedCity.value;
    if (city != null) {
      query = query.eq('city', city);
    }
    final search = _searchCtrl.text.trim();
    if (search.isNotEmpty) {
      query = query.ilike('title', '%$search%');
    }
    if (widget.carFilter) {
      if (_brand != null) query = query.eq('details->>brand', _brand!);
      if (_model != null) query = query.eq('details->>model', _model!);
      if (_generation != null) query = query.eq('details->>generation', _generation!);
      final priceMin = num.tryParse(_priceMinCtrl.text.trim());
      if (priceMin != null) query = query.gte('price', priceMin);
      final priceMax = num.tryParse(_priceMaxCtrl.text.trim());
      if (priceMax != null) query = query.lte('price', priceMax);
      final yearMin = int.tryParse(_yearMin ?? '');
      if (yearMin != null) query = query.gte('details->>year', '$yearMin');
    }
    final rows = await query.order('created_at', ascending: false).limit(100);
    final items = List<Map<String, dynamic>>.from(rows);
    if (mounted) setState(() => _count = items.length);
    return items;
  }

  void _reload() => setState(() => _future = _load());

  Widget _carFilterBlock() {
    InputDecoration dec(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF1F4F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );

    DropdownButtonFormField<String?> drop({
      required String hint,
      required String? value,
      required List<String> items,
      required String anyLabel,
      required ValueChanged<String?> onChanged,
    }) {
      return DropdownButtonFormField<String?>(
        value: value,
        isExpanded: true,
        decoration: dec(hint),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(anyLabel)),
          for (final i in items) DropdownMenuItem<String?>(value: i, child: Text(i)),
        ],
        onChanged: onChanged,
      );
    }

    final models = _brand == null ? <String>[] : (carCatalog[_brand]?.keys.toList() ?? <String>[]);

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
          drop(
            hint: 'Марка',
            value: _brand,
            items: carCatalog.keys.toList(),
            anyLabel: 'Все марки',
            onChanged: (v) => setState(() {
              _brand = v;
              _model = null;
            }),
          ),
          const SizedBox(height: 8),
          drop(
            hint: 'Модель',
            value: _model,
            items: models,
            anyLabel: _brand == null ? 'Сначала выберите марку' : 'Все модели',
            onChanged: (v) => setState(() {
              _model = v;
              _generation = null;
            }),
          ),
          if (_brand != null && _model != null) ...[
            const SizedBox(height: 8),
            drop(
              hint: 'Поколение',
              value: _generation,
              items: carCatalog[_brand]?[_model] ?? <String>[],
              anyLabel: (carCatalog[_brand]?[_model] ?? const <String>[]).isEmpty
                  ? 'Нет данных о поколениях'
                  : 'Все поколения',
              onChanged: (v) => setState(() => _generation = v),
            ),
            if (_generation != null) carGenerationPhoto(_brand!, _model!, _generation!),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceMinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: dec('Цена от'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _priceMaxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: dec('Цена до'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          drop(
            hint: 'Год выпуска от',
            value: _yearMin,
            items: carYears,
            anyLabel: 'Любой год',
            onChanged: (v) => setState(() => _yearMin = v),
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
      body: Column(
        children: [
          if (widget.carFilter) _carFilterBlock(),
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
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
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
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: GridView.count(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.66,
                    children: [for (final item in items) ListingCard(item: item)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
