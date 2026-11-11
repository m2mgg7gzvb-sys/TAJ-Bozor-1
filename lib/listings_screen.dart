import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'car_catalog.dart';
import 'city_store.dart';
import 'lang_store.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'laptop_catalog.dart';
import 'tech_catalog.dart';
import 'phone_catalog.dart';
import 'search_terms.dart';
import 'theme.dart';

/// Проверка числа из details (хранится текстом) по диапазону «от / до».
bool _inNumRange(Map d, String key, num? lo, num? hi) {
  if (lo == null && hi == null) return true;
  final v = num.tryParse('${d[key] ?? ''}'.replaceAll(',', '.').replaceAll(' ', ''));
  if (v == null) return false;
  return (lo == null || v >= lo) && (hi == null || v <= hi);
}

/// Лента объявлений. Может быть отфильтрована по категории и по поисковой строке.
/// Для категории «Авто» (carFilter) сверху показывается блок «Найти автомобиль».
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({
    super.key,
    this.categoryId,
    this.title = 'Объявления',
    this.initialQuery,
    this.carFilter = false,
    this.subcategoryId,
  });

  final int? categoryId;
  final int? subcategoryId;
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
  String? _bodyType;
  String? _fuel;
  String? _condition;
  String? _gearbox;
  String? _drive;
  String? _wheel;
  final _colorCtrl = TextEditingController();
  final _mileageMinCtrl = TextEditingController();
  final _mileageMaxCtrl = TextEditingController();
  final _engineMinCtrl = TextEditingController();
  final _engineMaxCtrl = TextEditingController();
  String? _country;
  String? _gai;
  String? _owners;
  String? _turbo;
  String? _seller;
  String? _option;
  String _sort = 'default';
  final _rangeCtrls = <String, (TextEditingController, TextEditingController)>{
    for (final k in const ['power_hp', 'fuel_consumption', 'acceleration', 'seats', 'trunk_l', 'clearance_mm'])
      k: (TextEditingController(), TextEditingController()),
  };
  late Future<List<Map<String, dynamic>>> _future;
  int? _count;

  /// Подкатегории выбранной категории и выбранная плитка.
  late Future<List<Map<String, dynamic>>> _subcats = _loadSubcats();
  int? _subcatId;

  /// Фильтры Телефонов (цена и цвет берутся из общих контроллеров).
  String? _pBrand;
  String? _pMemory;
  String? _pRam;
  String? _pSim;
  String? _pCondition;
  String? _pSeller;

  /// Открыт ли раздел «Электроника → Телефоны».
  bool get _isPhones => widget.categoryId == 3 && _subcatId == phoneSubcategoryId;

  /// Фильтры Ноутбуков.
  String? _lBrand;
  String? _lDiagonal;
  String? _lType;
  String? _lCpu;
  String? _lRam;
  String? _lStorage;
  String? _lGpu;
  String? _lOs;
  String? _lCondition;
  String? _lSeller;

  /// Открыт ли раздел «Электроника → Ноутбуки».
  bool get _isLaptops => widget.categoryId == 3 && _subcatId == laptopSubcategoryId;

  /// Фильтры остальных подкатегорий «Электроники» (ключ поля → выбранное значение).
  final _techFilters = <String, String?>{};
  final _techWordsCtrl = TextEditingController();
  final _techRangeCtrls = <String, (TextEditingController, TextEditingController)>{};
  (TextEditingController, TextEditingController) _techRange(String key) =>
      _techRangeCtrls.putIfAbsent(key, () => (TextEditingController(), TextEditingController()));

  /// Открыта ли одна из подкатегорий с общим набором характеристик.
  bool get _isTech => hasTech(widget.categoryId ?? -1, _subcatId);

  /// Старый фильтр авто (марка, модель и т.д.) — только там, где нет своего набора.
  bool get _carMode => widget.carFilter && !_isTech;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery ?? '';
    _subcatId = widget.subcategoryId;
    if (widget.categoryId == 2 && _subcatId == null) _techFilters['deal'] = 'Купить';
    _future = _load();
    selectedCity.addListener(_reload);
  }

  @override
  void dispose() {
    selectedCity.removeListener(_reload);
    _searchCtrl.dispose();
    _techWordsCtrl.dispose();
    for (final r in _techRangeCtrls.values) {
      r.$1.dispose();
      r.$2.dispose();
    }
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    _yearMinCtrl.dispose();
    _yearMaxCtrl.dispose();
    _colorCtrl.dispose();
    _mileageMinCtrl.dispose();
    _mileageMaxCtrl.dispose();
    _engineMinCtrl.dispose();
    _engineMaxCtrl.dispose();
    for (final r in _rangeCtrls.values) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  /// Справочник марок: для мотоциклов свой список.
  Map<String, Map<String, List<String>>> get _catalog =>
      widget.subcategoryId == motoSubcategoryId ? motoCatalog : carCatalog;

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
    if (_carMode) {
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
      if (_bodyType != null) query = query.eq('details->>body_type', _bodyType!);
      if (_fuel != null) query = query.eq('details->>fuel', _fuel!);
      if (_condition != null) query = query.eq('details->>condition', _condition!);
      if (_gearbox != null) query = query.eq('details->>gearbox', _gearbox!);
      if (_drive != null) query = query.eq('details->>drive', _drive!);
      if (_wheel != null) query = query.eq('details->>steering', _wheel!);
      final color = _colorCtrl.text.trim();
      if (color.isNotEmpty) query = query.eq('details->>color', color);
      if (_country != null) query = query.eq('details->>country', _country!);
      if (_gai != null) query = query.eq('details->>gai_registered', _gai!);
      if (_owners != null) query = query.eq('details->>owners', _owners!);
      if (_turbo != null) query = query.eq('details->>turbo', _turbo!);
      if (_seller != null) query = query.eq('details->>seller_type', _seller!);
      if (_option != null) query = query.ilike('details->>options', '%$_option%');
    }
    if (_isPhones) {
      if (_pBrand != null) query = query.eq('details->>brand', _pBrand!);
      if (_pMemory != null) query = query.eq('details->>memory', _pMemory!);
      if (_pRam != null) query = query.eq('details->>ram', _pRam!);
      if (_pSim != null) query = query.eq('details->>sim', _pSim!);
      if (_pCondition != null) query = query.eq('details->>condition', _pCondition!);
      if (_pSeller != null) query = query.eq('details->>seller_type', _pSeller!);
      final pColor = _colorCtrl.text.trim();
      if (pColor.isNotEmpty) query = query.ilike('details->>color', '%$pColor%');
      final pMin = num.tryParse(_priceMinCtrl.text.trim());
      if (pMin != null) query = query.gte('price', pMin);
      final pMax = num.tryParse(_priceMaxCtrl.text.trim());
      if (pMax != null) query = query.lte('price', pMax);
    }
    if (_isLaptops) {
      if (_lBrand != null) query = query.eq('details->>brand', _lBrand!);
      if (_lDiagonal != null) query = query.eq('details->>diagonal', _lDiagonal!);
      if (_lType != null) query = query.eq('details->>laptop_type', _lType!);
      if (_lCpu != null) query = query.eq('details->>cpu', _lCpu!);
      if (_lRam != null) query = query.eq('details->>ram', _lRam!);
      if (_lStorage != null) query = query.eq('details->>storage', _lStorage!);
      if (_lGpu != null) query = query.eq('details->>gpu', _lGpu!);
      if (_lOs != null) query = query.eq('details->>os', _lOs!);
      if (_lCondition != null) query = query.eq('details->>condition', _lCondition!);
      if (_lSeller != null) query = query.eq('details->>seller_type', _lSeller!);
      final lColor = _colorCtrl.text.trim();
      if (lColor.isNotEmpty) query = query.ilike('details->>color', '%$lColor%');
      final lMin = num.tryParse(_priceMinCtrl.text.trim());
      if (lMin != null) query = query.gte('price', lMin);
      final lMax = num.tryParse(_priceMaxCtrl.text.trim());
      if (lMax != null) query = query.lte('price', lMax);
    }
    if (_isTech) {
      _pruneTechFilters();
      for (final f in techFieldsFor(widget.categoryId ?? -1, _subcatId, _techFilters['property_type'])) {
        final v = _techFilters[f.key];
        if (v != null) query = query.eq('details->>${f.key}', v);
      }
      final tMin = num.tryParse(_priceMinCtrl.text.trim());
      if (tMin != null) query = query.gte('price', tMin);
      final tMax = num.tryParse(_priceMaxCtrl.text.trim());
      if (tMax != null) query = query.lte('price', tMax);
      final words = _techWordsCtrl.text.trim();
      if (words.isNotEmpty) query = query.ilike('description', '%$words%');
    }
    final order = switch (_sort) {
      'price_asc' => ('price', true),
      'price_desc' => ('price', false),
      'year' => ('details->>year', false),
      _ => ('created_at', false),
    };
    final rows = await query.order(order.$1, ascending: order.$2).limit(100);
    final items = List<Map<String, dynamic>>.from(rows);
    if (_isTech) {
      final rangeChecks = <(String, num?, num?)>[];
      for (final f in techFieldsFor(widget.categoryId ?? -1, _subcatId, _techFilters['property_type'])) {
        if (!f.range) continue;
        final c = _techRangeCtrls[f.key];
        if (c == null) continue;
        final lo = num.tryParse(c.$1.text.trim().replaceAll(',', '.'));
        final hi = num.tryParse(c.$2.text.trim().replaceAll(',', '.'));
        if (lo != null || hi != null) rangeChecks.add((f.key, lo, hi));
      }
      if (rangeChecks.isNotEmpty) {
        items.retainWhere((row) {
          final d = (row['details'] as Map?) ?? const {};
          return rangeChecks.every((c) {
            if (c.$1 == 'price_m2') {
              // Цена за м² не хранится: считаем из цены и площади.
              final area = num.tryParse('${d['area'] ?? ''}'.replaceAll(',', '.').replaceAll(' ', ''));
              final price = num.tryParse('${row['price'] ?? ''}');
              if (area == null || area == 0 || price == null) return false;
              final v = price / area;
              return (c.$2 == null || v >= c.$2!) && (c.$3 == null || v <= c.$3!);
            }
            return _inNumRange(d, c.$1, c.$2, c.$3);
          });
        });
      }
    }
    if (_carMode) {
      // Пробег и объём хранятся как текст, поэтому диапазон проверяем здесь.
      final mMin = num.tryParse(_mileageMinCtrl.text.trim());
      final mMax = num.tryParse(_mileageMaxCtrl.text.trim());
      final eMin = num.tryParse(_engineMinCtrl.text.trim().replaceAll(',', '.'));
      final eMax = num.tryParse(_engineMaxCtrl.text.trim().replaceAll(',', '.'));
      if (mMin != null || mMax != null || eMin != null || eMax != null) {
        bool inRange(Map d, String key, num? lo, num? hi) {
          if (lo == null && hi == null) return true;
          final v = num.tryParse('${d[key] ?? ''}'.replaceAll(',', '.').replaceAll(' ', ''));
          if (v == null) return false;
          return (lo == null || v >= lo) && (hi == null || v <= hi);
        }

        items.retainWhere((row) {
          final d = (row['details'] as Map?) ?? const {};
          return inRange(d, 'mileage_km', mMin, mMax) && inRange(d, 'engine_volume', eMin, eMax);
        });
      }
    }
    if (_carMode) {
      final checks = <(String, num?, num?)>[];
      for (final e in _rangeCtrls.entries) {
        final lo = num.tryParse(e.value.$1.text.trim().replaceAll(',', '.'));
        final hi = num.tryParse(e.value.$2.text.trim().replaceAll(',', '.'));
        if (lo != null || hi != null) checks.add((e.key, lo, hi));
      }
      if (checks.isNotEmpty) {
        items.retainWhere((row) {
          final d = (row['details'] as Map?) ?? const {};
          return checks.every((c) => _inNumRange(d, c.$1, c.$2, c.$3));
        });
      }
    }
    if (_sort == 'mileage') {
      // Пробег хранится текстом, поэтому сортируем здесь: без пробега в конце.
      double km(Map<String, dynamic> row) {
        final d = (row['details'] as Map?) ?? const {};
        return num.tryParse('${d['mileage_km'] ?? ''}'.replaceAll(' ', ''))?.toDouble() ?? double.infinity;
      }

      items.sort((a, b) => km(a).compareTo(km(b)));
    }
    if (rank.isNotEmpty) {
      // При поиске сначала самые похожие на запрос.
      items.sort((a, b) => (rank[a['id']] ?? 1 << 30).compareTo(rank[b['id']] ?? 1 << 30));
    }
    if (mounted) setState(() => _count = items.length);
    return items;
  }

  void _reload() => setState(() => _future = _load());

  /// Выполнить выбор в чипе и сразу обновить ленту.
  Future<void> _thenReload(Future<void> Function() action) async {
    await action();
    if (mounted) _reload();
  }

  Future<List<Map<String, dynamic>>> _loadSubcats() async {
    if (widget.categoryId == null) return [];
    try {
      final rows = await Supabase.instance.client
          .from('subcategories')
          .select('id, name_ru')
          .eq('category_id', widget.categoryId!)
          .order('sort', ascending: true);
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

  /// 3D-иконки подкатегорий. Если картинки нет, показываем Material-иконку из _subcatIcon.
  String? _subcatImage(String name) {
    final n = name.toLowerCase();
    if (n.contains('телефон')) return 'assets/icons/phone.png';
    if (n.contains('новые авто')) return 'assets/icons/new-cars.png';
    if (n.contains('селект')) return 'assets/icons/select.png';
    if (n.contains('легков')) return 'assets/icons/auto.png';
    if (n.contains('грузов')) return 'assets/icons/trucks.png';
    if (n.contains('мото')) return 'assets/icons/moto.png';
    if (n.contains('аренда авто')) return 'assets/icons/rent-car.png';
    if (n.contains('аренда техники')) return 'assets/icons/rent-tech.png';
    if (n.contains('запчаст')) return 'assets/icons/parts.png';
    return null;
  }

  Widget _subcatRow() {
    // На странице подкатегории плитки уже не нужны.
    if (widget.subcategoryId != null) return const SizedBox.shrink();
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

  /// Ряды плиток: 3, 2, 3, 2 и так по кругу (как на Авито).
  List<List<Map<String, dynamic>>> _tileRows(List<Map<String, dynamic>> subs) {
    final rows = <List<Map<String, dynamic>>>[];
    var i = 0;
    var wide = false;
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListingsScreen(
              categoryId: widget.categoryId,
              subcategoryId: id,
              title: name,
              carFilter: widget.carFilter,
            ),
          ),
        ),
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                child: _subcatImage(name) != null
                    ? Image.asset(_subcatImage(name)!, width: wide ? 44 : 40, height: wide ? 44 : 40, fit: BoxFit.contain)
                    : Icon(
                        _subcatIcon(name),
                        size: wide ? 40 : 36,
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

  /// Выбор из списка в нижнем окне с поиском. Пустая строка значит «любой».
  Future<String?> _pickFromList({
    required String title,
    required List<String> items,
    required String anyLabel,
    String? current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PickerSheet(title: title, items: items, anyLabel: anyLabel, current: current),
    );
  }

  /// Карточка нижнего окна: скругления, индикатор, заголовок.
  Widget _sheetCard(BuildContext ctx, {required String title, required List<Widget> children}) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9DEDC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF1F1F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _sheetButton(String text, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: onTap,
        child: Text(text),
      );

  /// Диапазон «от» и «до» (цена или год) в нижнем окне.
  Future<void> _rangeSheet({
    required String title,
    required TextEditingController from,
    required TextEditingController to,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetCard(
        ctx,
        title: title,
        children: [
          Row(
            children: [
              Expanded(child: _sheetField(from, 'от')),
              const SizedBox(width: 10),
              Expanded(child: _sheetField(to, 'до')),
            ],
          ),
          const SizedBox(height: 16),
          _sheetButton('Готово', () {
            setState(() {});
            Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  Future<void> _pickBrandAndModel() async {
    final brand = await _pickFromList(
      title: 'Марка',
      items: _catalog.keys.toList(),
      anyLabel: 'Все марки',
      current: _brand,
    );
    if (brand == null) return;
    setState(() {
      _brand = brand.isEmpty ? null : brand;
      _model = null;
      _generation = null;
    });
    if (brand.isEmpty) return;
    // Сразу после выбора марки открываем список моделей.
    await _pickModel();
  }

  Future<void> _pickModel() async {
    final model = await _pickFromList(
      title: 'Модель',
      items: _catalog[_brand]?.keys.toList() ?? <String>[],
      anyLabel: 'Все модели',
      current: _model,
    );
    if (model == null) return;
    setState(() {
      _model = model.isEmpty ? null : model;
      _generation = null;
    });
  }

  Future<void> _pickGeneration(List<String> generations) async {
    final gen = await _pickFromList(
      title: 'Поколение',
      items: generations,
      anyLabel: 'Все поколения',
      current: _generation,
    );
    if (gen == null) return;
    setState(() => _generation = gen.isEmpty ? null : gen);
  }

  /// Текст диапазона «от / до» или null, если диапазон не задан.
  String? _rangeText(TextEditingController a, TextEditingController b) {
    final from = a.text.trim();
    final to = b.text.trim();
    if (from.isEmpty && to.isEmpty) return null;
    if (from.isNotEmpty && to.isNotEmpty) return 'от $from до $to';
    return from.isNotEmpty ? 'от $from' : 'до $to';
  }

  Widget _chip(
    String label, {
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
    bool arrow = true,
  }) {
    final fg = active ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? AppColors.primary : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: active ? AppColors.primary : const Color(0xFFD9DEDC)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
                if (arrow) Icon(Icons.arrow_drop_down, size: 20, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ряд быстрых фильтров под поиском (как на Авито).
  Widget _carChipsRow() {
    final priceText = _rangeText(_priceMinCtrl, _priceMaxCtrl);
    final yearText = _rangeText(_yearMinCtrl, _yearMaxCtrl);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(_brand ?? 'Марка', active: _brand != null, onTap: () => _thenReload(_pickBrandAndModel)),
          if (_brand != null)
            _chip(_model ?? 'Модель', active: _model != null, onTap: () => _thenReload(_pickModel)),
          _chip(
            priceText == null ? 'Цена' : 'Цена: $priceText',
            active: priceText != null,
            onTap: () => _thenReload(() => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl)),
          ),
          _chip(
            yearText == null ? 'Год' : 'Год: $yearText',
            active: yearText != null,
            onTap: () => _thenReload(() => _rangeSheet(title: 'Год выпуска', from: _yearMinCtrl, to: _yearMaxCtrl)),
          ),
          _chip(
            'Фильтры',
            active: false,
            arrow: false,
            icon: Icons.tune_rounded,
            onTap: _openCarFilters,
          ),
        ],
      ),
    );
  }

  /// Ряд быстрых фильтров для Телефонов.
  Widget _phoneChipsRow() {
    final priceText = _rangeText(_priceMinCtrl, _priceMaxCtrl);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            _pBrand ?? 'Производитель',
            active: _pBrand != null,
            onTap: () => _thenReload(() => _pickValue('Производитель', phoneBrands, (v) => _pBrand = v, current: _pBrand)),
          ),
          _chip(
            _pMemory ?? 'Память',
            active: _pMemory != null,
            onTap: () => _thenReload(() => _pickValue('Память', phoneMemory, (v) => _pMemory = v, current: _pMemory)),
          ),
          _chip(
            priceText == null ? 'Цена' : 'Цена: $priceText',
            active: priceText != null,
            onTap: () => _thenReload(() => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl)),
          ),
          _chip(
            'Фильтры',
            active: false,
            arrow: false,
            icon: Icons.tune_rounded,
            onTap: _openPhoneFilters,
          ),
        ],
      ),
    );
  }

  /// Фильтры Телефонов на весь экран.
  void _openPhoneFilters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setPage) {
            void rebuild() => setPage(() {});

            Future<void> pick(Future<void> Function() action) async {
              await action();
              rebuild();
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: const Text('Фильтры', style: TextStyle(fontWeight: FontWeight.w800)),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetPhoneFilters();
                      rebuild();
                    },
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const Text(
                    'Телефоны',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                  _fLabel('Состояние'),
                  _fChips(
                    ['Все', ...phoneConditions],
                    _pCondition ?? 'Все',
                    (v) {
                      _pCondition = v == 'Все' ? null : v;
                      rebuild();
                    },
                  ),
                  _fLabel('Цена'),
                  _fRange(_priceMinCtrl, _priceMaxCtrl, 'От', 'до'),
                  _fLabel('Производитель'),
                  _fBox(
                    _pBrand ?? 'Любой',
                    _pBrand != null,
                    () => pick(() => _pickValue('Производитель', phoneBrands, (v) => _pBrand = v, current: _pBrand)),
                  ),
                  _fLabel('Память'),
                  _fBox(
                    _pMemory ?? 'Любая',
                    _pMemory != null,
                    () => pick(() => _pickValue('Память', phoneMemory, (v) => _pMemory = v, current: _pMemory)),
                  ),
                  _fLabel('Оперативная память'),
                  _fBox(
                    _pRam ?? 'Любая',
                    _pRam != null,
                    () => pick(() => _pickValue('Оперативная память', phoneRam, (v) => _pRam = v, current: _pRam)),
                  ),
                  _fLabel('SIM-карты'),
                  _fBox(
                    _pSim ?? 'Любые',
                    _pSim != null,
                    () => pick(() => _pickValue('SIM-карты', phoneSims, (v) => _pSim = v, current: _pSim)),
                  ),
                  _fLabel('Цвет'),
                  _fBox(
                    _colorCtrl.text.isEmpty ? 'Любой' : _colorCtrl.text,
                    _colorCtrl.text.isNotEmpty,
                    () => pick(() => _textSheet(title: 'Цвет', ctrl: _colorCtrl)),
                  ),
                  _fLabel('Продавец'),
                  _fChips(
                    ['Все', ...phoneSellers],
                    _pSeller ?? 'Все',
                    (v) {
                      _pSeller = v == 'Все' ? null : v;
                      rebuild();
                    },
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reload();
                    },
                    child: const Text('Показать объявления'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Сбрасывает все параметры Телефонов.
  void _resetPhoneFilters() {
    setState(() {
      _pBrand = null;
      _pMemory = null;
      _pRam = null;
      _pSim = null;
      _pCondition = null;
      _pSeller = null;
    });
    _priceMinCtrl.clear();
    _priceMaxCtrl.clear();
    _colorCtrl.clear();
  }

  /// Ряд быстрых фильтров для Ноутбуков.
  Widget _laptopChipsRow() {
    final priceText = _rangeText(_priceMinCtrl, _priceMaxCtrl);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(
            _lBrand ?? 'Производитель',
            active: _lBrand != null,
            onTap: () => _thenReload(() => _pickValue('Производитель', laptopBrands, (v) => _lBrand = v, current: _lBrand)),
          ),
          _chip(
            _lDiagonal ?? 'Диагональ',
            active: _lDiagonal != null,
            onTap: () => _thenReload(() => _pickValue('Диагональ экрана, дюйм', laptopDiagonals, (v) => _lDiagonal = v, current: _lDiagonal)),
          ),
          _chip(
            priceText == null ? 'Цена' : 'Цена: $priceText',
            active: priceText != null,
            onTap: () => _thenReload(() => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl)),
          ),
          _chip(
            'Фильтры',
            active: false,
            arrow: false,
            icon: Icons.tune_rounded,
            onTap: _openLaptopFilters,
          ),
        ],
      ),
    );
  }

  /// Фильтры Ноутбуков на весь экран.
  void _openLaptopFilters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setPage) {
            void rebuild() => setPage(() {});

            Future<void> pick(Future<void> Function() action) async {
              await action();
              rebuild();
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: const Text('Фильтры', style: TextStyle(fontWeight: FontWeight.w800)),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetLaptopFilters();
                      rebuild();
                    },
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const Text(
                    'Ноутбуки',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                  _fLabel('Состояние'),
                  _fChips(
                    ['Все', ...phoneConditions],
                    _lCondition ?? 'Все',
                    (v) {
                      _lCondition = v == 'Все' ? null : v;
                      rebuild();
                    },
                  ),
                  _fLabel('Цена'),
                  _fRange(_priceMinCtrl, _priceMaxCtrl, 'От', 'до'),
                  _fLabel('Производитель'),
                  _fBox(
                    _lBrand ?? 'Любой',
                    _lBrand != null,
                    () => pick(() => _pickValue('Производитель', laptopBrands, (v) => _lBrand = v, current: _lBrand)),
                  ),
                  _fLabel('Тип ноутбука'),
                  _fChips(
                    ['Все', ...laptopTypes],
                    _lType ?? 'Все',
                    (v) {
                      _lType = v == 'Все' ? null : v;
                      rebuild();
                    },
                  ),
                  _fLabel('Диагональ экрана, дюйм'),
                  _fBox(
                    _lDiagonal ?? 'Любая',
                    _lDiagonal != null,
                    () => pick(() => _pickValue('Диагональ экрана, дюйм', laptopDiagonals, (v) => _lDiagonal = v, current: _lDiagonal)),
                  ),
                  _fLabel('Процессор'),
                  _fBox(
                    _lCpu ?? 'Любой',
                    _lCpu != null,
                    () => pick(() => _pickValue('Процессор', laptopCpus, (v) => _lCpu = v, current: _lCpu)),
                  ),
                  _fLabel('Оперативная память'),
                  _fBox(
                    _lRam ?? 'Любая',
                    _lRam != null,
                    () => pick(() => _pickValue('Оперативная память', laptopRam, (v) => _lRam = v, current: _lRam)),
                  ),
                  _fLabel('Накопитель'),
                  _fBox(
                    _lStorage ?? 'Любой',
                    _lStorage != null,
                    () => pick(() => _pickValue('Накопитель', laptopStorage, (v) => _lStorage = v, current: _lStorage)),
                  ),
                  _fLabel('Видеокарта'),
                  _fBox(
                    _lGpu ?? 'Любая',
                    _lGpu != null,
                    () => pick(() => _pickValue('Видеокарта', laptopGpus, (v) => _lGpu = v, current: _lGpu)),
                  ),
                  _fLabel('Операционная система'),
                  _fBox(
                    _lOs ?? 'Любая',
                    _lOs != null,
                    () => pick(() => _pickValue('Операционная система', laptopOs, (v) => _lOs = v, current: _lOs)),
                  ),
                  _fLabel('Цвет'),
                  _fBox(
                    _colorCtrl.text.isEmpty ? 'Любой' : _colorCtrl.text,
                    _colorCtrl.text.isNotEmpty,
                    () => pick(() => _textSheet(title: 'Цвет', ctrl: _colorCtrl)),
                  ),
                  _fLabel('Продавцы'),
                  _fChips(
                    ['Все', ...phoneSellers],
                    _lSeller ?? 'Все',
                    (v) {
                      _lSeller = v == 'Все' ? null : v;
                      rebuild();
                    },
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reload();
                    },
                    child: const Text('Показать объявления'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Сбрасывает все параметры Ноутбуков.
  void _resetLaptopFilters() {
    setState(() {
      _lBrand = null;
      _lDiagonal = null;
      _lType = null;
      _lCpu = null;
      _lRam = null;
      _lStorage = null;
      _lGpu = null;
      _lOs = null;
      _lCondition = null;
      _lSeller = null;
    });
    _priceMinCtrl.clear();
    _priceMaxCtrl.clear();
    _colorCtrl.clear();
  }

  /// Ряд быстрых фильтров для подкатегорий с общим набором характеристик.
  Widget _techChipsRow() {
    final priceText = _rangeText(_priceMinCtrl, _priceMaxCtrl);
    final fields = techFieldsFor(widget.categoryId ?? -1, _subcatId, _techFilters['property_type']);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final f in fields.take(2))
            _chip(
              _techFilters[f.key] ?? f.label,
              active: _techFilters[f.key] != null,
              onTap: () => _thenReload(() => _pickValue(f.label, f.options, (v) => _techFilters[f.key] = v, current: _techFilters[f.key])),
            ),
          _chip(
            priceText == null ? 'Цена' : 'Цена: $priceText',
            active: priceText != null,
            onTap: () => _thenReload(() => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl)),
          ),
          _chip(
            'Фильтры',
            active: false,
            arrow: false,
            icon: Icons.tune_rounded,
            onTap: _openTechFilters,
          ),
        ],
      ),
    );
  }

  /// Фильтры подкатегории на весь экран.
  void _openTechFilters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setPage) {
            void rebuild() => setPage(() {});

            Future<void> pick(Future<void> Function() action) async {
              await action();
              rebuild();
            }

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: const Text('Фильтры', style: TextStyle(fontWeight: FontWeight.w800)),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetTechFilters();
                      rebuild();
                    },
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                  _fLabel('Цена'),
                  _fRange(_priceMinCtrl, _priceMaxCtrl, 'От', 'до'),
                  for (final f in techFieldsFor(widget.categoryId ?? -1, _subcatId, _techFilters['property_type'])) ...[
                    _fLabel(f.label),
                    if (f.range)
                      _fRange(_techRange(f.key).$1, _techRange(f.key).$2, 'От', 'до')
                    else if (f.options.length <= 4)
                      _fChips(
                        ['Все', ...f.options],
                        _techFilters[f.key] ?? 'Все',
                        (v) {
                          _techFilters[f.key] = v == 'Все' ? null : v;
                          rebuild();
                        },
                      )
                    else
                      _fBox(
                        _techFilters[f.key] ?? 'Любой',
                        _techFilters[f.key] != null,
                        () => pick(() => _pickValue(f.label, f.options, (v) => _techFilters[f.key] = v, current: _techFilters[f.key])),
                      ),
                  ],
                  _fLabel('Сортировка'),
                  _fChips(
                    const ['По умолчанию', 'Дешевле', 'Дороже'],
                    _sort == 'price_asc' ? 'Дешевле' : (_sort == 'price_desc' ? 'Дороже' : 'По умолчанию'),
                    (v) {
                      _sort = v == 'Дешевле' ? 'price_asc' : (v == 'Дороже' ? 'price_desc' : 'default');
                      rebuild();
                    },
                  ),
                  _fLabel('Слова в описании'),
                  TextField(
                    controller: _techWordsCtrl,
                    decoration: InputDecoration(
                      hintText: 'Что-то важное для вас',
                      filled: true,
                      fillColor: const Color(0xFFF1F1F1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reload();
                    },
                    child: const Text('Показать объявления'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Убирает фильтры, которых нет в наборе выбранного типа (например, после смены типа недвижимости).
  void _pruneTechFilters() {
    final keys = {for (final f in techFieldsFor(widget.categoryId ?? -1, _subcatId, _techFilters['property_type'])) f.key};
    _techFilters.removeWhere((k, _) => !keys.contains(k));
  }

  /// Сбрасывает фильтры подкатегории с общим набором характеристик.
  void _resetTechFilters() {
    setState(() {
      _techFilters.clear();
      if (_isRealEstateTop) _techFilters['deal'] = 'Купить';
      _sort = 'default';
    });
    _priceMinCtrl.clear();
    _priceMaxCtrl.clear();
    _techWordsCtrl.clear();
    for (final r in _techRangeCtrls.values) {
      r.$1.clear();
      r.$2.clear();
    }
  }

  /// Верхний блок раздела «Недвижимость» (как на эталоне): город, сделка, поля, кнопки.
  bool get _isRealEstateTop => widget.categoryId == 2 && _subcatId == null;

  ButtonStyle get _blackBtn => FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _realEstateBlock() {
    final fields = {for (final f in techFieldsFor(2, null)) f.key: f};
    String? val(String k) => _techFilters[k];
    final propertyType = val('property_type');
    final isFlat = propertyType == null || propertyType == 'Квартиры';
    final deal = val('deal') ?? 'Купить';
    final priceText = _rangeText(_priceMinCtrl, _priceMaxCtrl);
    final pt = fields['property_type']!;
    final nos = fields['new_or_secondary']!;
    final rooms = fields['rooms']!;

    final cityRow = Material(
      color: const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showCityPicker(context).then((_) {
          if (mounted) _reload();
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 4),
              Text(
                selectedCity.value ?? 'Все города',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ),
    );

    final dealTabs = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final d in fields['deal']!.options.where((d) => isFlat || d != 'Посуточно'))
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _techFilters['deal'] = d);
                  _reload();
                },
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: d == deal ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: d == deal ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final priceBox = _fBox(
      priceText ?? 'Цена',
      priceText != null,
      () => _thenReload(() => _rangeSheet(title: 'Цена', from: _priceMinCtrl, to: _priceMaxCtrl)),
    );

    final showBtn = FilledButton(
      style: _blackBtn,
      onPressed: () => _reload(),
      child: const Text('Показать объявления'),
    );

    final typeBtn = OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Colors.black, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => _thenReload(
        () => _pickValue(pt.label, pt.options, (v) => _techFilters['property_type'] = v, current: propertyType),
      ),
      child: Text(propertyType ?? pt.label),
    );

    final filterBtn = Material(
      color: const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openTechFilters,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.tune_rounded),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          cityRow,
          const SizedBox(height: 12),
          dealTabs,
          const SizedBox(height: 8),
          if (isFlat) ...[
            _fBox(
              val('new_or_secondary') ?? nos.label,
              val('new_or_secondary') != null,
              () => _thenReload(() => _pickValue(nos.label, nos.options, (v) => _techFilters['new_or_secondary'] = v, current: val('new_or_secondary'))),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _fBox(
                    val('rooms') ?? rooms.label,
                    val('rooms') != null,
                    () => _thenReload(() => _pickValue(rooms.label, rooms.options, (v) => _techFilters['rooms'] = v, current: val('rooms'))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: priceBox),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: showBtn),
                const SizedBox(width: 8),
                filterBtn,
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: typeBtn),
          ] else ...[
            Row(
              children: [
                Expanded(child: showBtn),
                const SizedBox(width: 8),
                Expanded(child: priceBox),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: typeBtn),
                const SizedBox(width: 8),
                filterBtn,
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sheetTile(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
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
                  value == null ? label : '$label: $value',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null ? Colors.black54 : Colors.black87,
                    fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

  /// Выбор значения из списка в текстовый контроллер; «Любой» очищает.
  Future<void> _pickToCtrl(String title, List<String> items, TextEditingController ctrl) async {
    final v = await _pickFromList(title: title, items: items, anyLabel: 'Любой', current: ctrl.text);
    if (v == null) return;
    setState(() => ctrl.text = v);
  }

  /// Объём двигателя «от» и «до» — два выбора из списка.
  Future<void> _pickEngineRange() async {
    await _pickToCtrl('Объём от, л', carEngineVolumes, _engineMinCtrl);
    if (!mounted) return;
    await _pickToCtrl('Объём до, л', carEngineVolumes, _engineMaxCtrl);
  }

  /// Выбор одного значения из списка; пункт «Не важно» сбрасывает фильтр.
  Future<void> _pickValue(
    String title,
    List<String> values,
    void Function(String?) assign, {
    String? current,
  }) async {
    final v = await _pickFromList(title: title, items: values, anyLabel: 'Не важно', current: current);
    if (v == null) return;
    setState(() => assign(v.isEmpty ? null : v));
  }

  /// Одно текстовое поле в нижнем окне (например, цвет).
  Future<void> _textSheet({required String title, required TextEditingController ctrl}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetCard(
        ctx,
        title: title,
        children: [
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'Например, белый',
              filled: true,
              fillColor: const Color(0xFFF1F1F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sheetButton('Готово', () {
            setState(() {});
            Navigator.pop(ctx);
          }),
        ],
      ),
    );
  }

  /// Фильтры Авто на весь экран, в стиле Авито.
  void _openCarFilters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setPage) {
            void rebuild() => setPage(() {});

            Future<void> pick(Future<void> Function() action) async {
              await action();
              rebuild();
            }

            final generations = (_brand != null && _model != null)
                ? (_catalog[_brand]?[_model] ?? <String>[])
                : <String>[];

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: const Text('Фильтры', style: TextStyle(fontWeight: FontWeight.w800)),
                centerTitle: true,
                actions: [
                  TextButton(
                    onPressed: () {
                      _resetCarFilters();
                      rebuild();
                    },
                    child: const Text('Сбросить'),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  const Text(
                    'Автомобили',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                  _fLabel('Состояние'),
                  _fChips(
                    const ['Все', 'Новые', 'С пробегом'],
                    _condition == null ? 'Все' : (_condition == 'Новый' ? 'Новые' : 'С пробегом'),
                    (v) {
                      _condition = v == 'Все' ? null : (v == 'Новые' ? 'Новый' : 'С пробегом');
                      rebuild();
                    },
                  ),
                  _fLabel('Цена'),
                  _fRange(_priceMinCtrl, _priceMaxCtrl, 'От', 'до'),
                  _fLabel('Страна бренда'),
                  _fBox(
                    _country ?? 'Все',
                    _country != null,
                    () => pick(() => _pickValue('Страна бренда', carCountries, (v) => _country = v, current: _country)),
                  ),
                  _fLabel('Марка'),
                  _fBox(_brand ?? 'Любая', _brand != null, () => pick(_pickBrandAndModel)),
                  if (_brand != null) ...[
                    _fLabel('Модель'),
                    _fBox(_model ?? 'Любая', _model != null, () => pick(_pickModel)),
                  ],
                  if (generations.isNotEmpty) ...[
                    _fLabel('Поколение'),
                    _fBox(
                      _generation ?? 'Любое',
                      _generation != null,
                      () => pick(() => _pickGeneration(generations)),
                    ),
                  ],
                  _fLabel('Кузов'),
                  _fBox(
                    _bodyType ?? 'Любой',
                    _bodyType != null,
                    () => pick(() => _pickValue('Кузов', carBodyTypes, (v) => _bodyType = v, current: _bodyType)),
                  ),
                  _fLabel('Год выпуска'),
                  _fRange(_yearMinCtrl, _yearMaxCtrl, 'От', 'до'),
                  _fLabel('Пробег, км'),
                  _fRange(_mileageMinCtrl, _mileageMaxCtrl, 'От', 'до'),
                  _fLabel('Регистрация в ГАИ'),
                  _fChips(
                    const ['Не важно', 'Есть', 'Нет'],
                    _gai ?? 'Не важно',
                    (v) {
                      _gai = v == 'Не важно' ? null : v;
                      rebuild();
                    },
                  ),
                  _fLabel('Владельцев по ПТС'),
                  _fChips(
                    ['Не важно', ...carOwners],
                    _owners ?? 'Не важно',
                    (v) {
                      _owners = v == 'Не важно' ? null : v;
                      rebuild();
                    },
                  ),
                  _fLabel('Продавец'),
                  _fChips(
                    const ['Все', 'Дилеры', 'Частные'],
                    _seller == null ? 'Все' : (_seller == 'Дилер' ? 'Дилеры' : 'Частные'),
                    (v) {
                      _seller = v == 'Все' ? null : (v == 'Дилеры' ? 'Дилер' : 'Частный');
                      rebuild();
                    },
                  ),
                  _fLabel('Двигатель'),
                  _fBox(
                    _fuel ?? 'Любой',
                    _fuel != null,
                    () => pick(() => _pickValue('Топливо', carFuels, (v) => _fuel = v, current: _fuel)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _fBox(
                          _engineMinCtrl.text.isEmpty ? 'Объём от' : _engineMinCtrl.text,
                          _engineMinCtrl.text.isNotEmpty,
                          () => pick(() => _pickToCtrl('Объём от, л', carEngineVolumes, _engineMinCtrl)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _fBox(
                          _engineMaxCtrl.text.isEmpty ? 'Объём до' : _engineMaxCtrl.text,
                          _engineMaxCtrl.text.isNotEmpty,
                          () => pick(() => _pickToCtrl('Объём до, л', carEngineVolumes, _engineMaxCtrl)),
                        ),
                      ),
                    ],
                  ),
                  _fLabel('Коробка передач'),
                  _fBox(
                    _gearbox ?? 'Любая',
                    _gearbox != null,
                    () => pick(() => _pickValue('Коробка передач', carGearboxes, (v) => _gearbox = v, current: _gearbox)),
                  ),
                  _fLabel('Привод'),
                  _fBox(
                    _drive ?? 'Любой',
                    _drive != null,
                    () => pick(() => _pickValue('Привод', carDrives, (v) => _drive = v, current: _drive)),
                  ),
                  _fLabel('Руль'),
                  _fBox(
                    _wheel ?? 'Любой',
                    _wheel != null,
                    () => pick(() => _pickValue('Руль', carWheels, (v) => _wheel = v, current: _wheel)),
                  ),
                  _fLabel('Мощность, л.с.'),
                  _fRange(_rangeCtrls['power_hp']!.$1, _rangeCtrls['power_hp']!.$2, 'От', 'до'),
                  _fLabel('Расход на 100 км, л'),
                  _fRange(_rangeCtrls['fuel_consumption']!.$1, _rangeCtrls['fuel_consumption']!.$2, 'От', 'до', decimal: true),
                  _fLabel('Разгон до 100 км/ч, сек'),
                  _fRange(_rangeCtrls['acceleration']!.$1, _rangeCtrls['acceleration']!.$2, 'От', 'до', decimal: true),
                  _fLabel('Количество мест'),
                  _fRange(_rangeCtrls['seats']!.$1, _rangeCtrls['seats']!.$2, 'От', 'до'),
                  _fLabel('Объём багажника, л'),
                  _fRange(_rangeCtrls['trunk_l']!.$1, _rangeCtrls['trunk_l']!.$2, 'От', 'до'),
                  _fLabel('Клиренс, мм'),
                  _fRange(_rangeCtrls['clearance_mm']!.$1, _rangeCtrls['clearance_mm']!.$2, 'От', 'до'),
                  _fLabel('Цвет'),
                  _fBox(
                    _colorCtrl.text.isEmpty ? 'Любой' : _colorCtrl.text,
                    _colorCtrl.text.isNotEmpty,
                    () => pick(() => _pickToCtrl('Цвет', carColors, _colorCtrl)),
                  ),
                  _fLabel('Опции'),
                  _fBox(
                    _option ?? 'Любые',
                    _option != null,
                    () => pick(() => _pickValue('Опция', carOptions, (v) => _option = v, current: _option)),
                  ),
                  _fLabel('Турбина'),
                  _fChips(
                    const ['Не важно', 'Есть', 'Нет'],
                    _turbo == null ? 'Не важно' : (_turbo == 'Да' ? 'Есть' : 'Нет'),
                    (v) {
                      _turbo = v == 'Не важно' ? null : (v == 'Есть' ? 'Да' : 'Нет');
                      rebuild();
                    },
                  ),
                  _fLabel('Сортировка'),
                  for (final o in const [
                    ('default', 'По умолчанию'),
                    ('price_asc', 'Дешевле'),
                    ('price_desc', 'Дороже'),
                    ('year', 'По году выпуска'),
                    ('mileage', 'По пробегу'),
                  ])
                    InkWell(
                      onTap: () {
                        _sort = o.$1;
                        rebuild();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              _sort == o.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 12),
                            Text(o.$2, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reload();
                    },
                    child: const Text('Показать объявления'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Сбрасывает все параметры Авто.
  void _resetCarFilters() {
    setState(() {
      _brand = null;
      _model = null;
      _generation = null;
      _condition = null;
      _country = null;
      _bodyType = null;
      _fuel = null;
      _gearbox = null;
      _drive = null;
      _wheel = null;
      _gai = null;
      _owners = null;
      _turbo = null;
      _seller = null;
      _option = null;
      _sort = 'default';
    });
    for (final c in [
      _priceMinCtrl,
      _priceMaxCtrl,
      _yearMinCtrl,
      _yearMaxCtrl,
      _mileageMinCtrl,
      _mileageMaxCtrl,
      _engineMinCtrl,
      _engineMaxCtrl,
      _colorCtrl,
      for (final r in _rangeCtrls.values) ...[r.$1, r.$2],
    ]) {
      c.clear();
    }
  }

  Widget _fLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );

  /// Серое поле-выбор со стрелкой.
  Widget _fBox(String text, bool filled, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: filled ? Colors.black : Colors.black45),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  /// Два поля «от» и «до» в ряд.
  Widget _fRange(
    TextEditingController a,
    TextEditingController b,
    String hintA,
    String hintB, {
    bool decimal = false,
  }) {
    final kb = decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number;
    Widget box(TextEditingController c, String hint) => TextField(
          controller: c,
          keyboardType: kb,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF1F1F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
    return Row(
      children: [
        Expanded(child: box(a, hintA)),
        const SizedBox(width: 8),
        Expanded(child: box(b, hintB)),
      ],
    );
  }

  /// Чипы: выбранный обведён чёрной рамкой.
  Widget _fChips(List<String> items, String selected, ValueChanged<String> onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final i in items)
          InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i == selected ? Colors.white : const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: i == selected ? Colors.black : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(i, style: const TextStyle(fontSize: 15)),
            ),
          ),
      ],
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
          _subcatRow(),
          if (_carMode) _carChipsRow(),
          if (_isPhones) _phoneChipsRow(),
          if (_isLaptops) _laptopChipsRow(),
          if (_isTech && !_isRealEstateTop) _techChipsRow(),
          if (_isRealEstateTop) _realEstateBlock(),
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

/// Список выбора с поиском: марки, модели, поколения и любые значения.
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.title, required this.items, required this.anyLabel, this.current});

  final String title;
  final List<String> items;
  final String anyLabel;
  final String? current;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _row(String text, {required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? const Color(0xFFE8F3EF) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : Colors.black87,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((i) => i.toLowerCase().contains(q)).toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEDC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${widget.items.length}',
                    style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (widget.items.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF1F1F1),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  _row(
                    widget.anyLabel,
                    selected: widget.current == null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                  for (final i in shown)
                    _row(
                      i,
                      selected: i == widget.current,
                      onTap: () => Navigator.pop(context, i),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
