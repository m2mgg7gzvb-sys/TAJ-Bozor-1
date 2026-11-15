import 'search_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'all_categories_screen.dart';
import 'city_store.dart';
import 'fade_route.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'lang_store.dart';
import 'listings_screen.dart';
import 'nav_state.dart';
import 'frosted_glass.dart';
import 'promote_sheet.dart';
import 'glass_widgets.dart';
import 'theme.dart';
import 'green_button.dart';

/// Главная вкладка «Поиск»: поиск, баннер, категории и новые объявления.
const _tgCats = {
  'real-estate': 'Амлок',
  'jobs': 'Кор ва музднон',
  'auto': 'Нақлиёт',
  'electronics': 'Электроника',
  'services': 'Хизматҳо',
  'home': 'Барои хона',
};

String _catName(Map<String, dynamic> c) {
  final ru = c['name_ru'] as String;
  final slug = c['slug'] as String?;
  return tr(ru, _tgCats[slug] ?? ru);
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Map<String, dynamic>>> _listings;
  late Future<List<Map<String, dynamic>>> _categories;

  @override
  void initState() {
    super.initState();
    _listings = _loadListings();
    _categories = _loadCategories();
    selectedCity.addListener(_onCityChanged);
    loadSelectedCity();
  }

  @override
  void dispose() {
    selectedCity.removeListener(_onCityChanged);
    super.dispose();
  }

  void _onCityChanged() => _refresh();

  Future<List<Map<String, dynamic>>> _loadListings() async {
    final city = selectedCity.value;
    // Объявления с действующим TOP идут первыми (срок — listings.top_until).
    var topQuery = Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .gt('top_until', DateTime.now().toUtc().toIso8601String());
    if (city != null) topQuery = topQuery.eq('city', city);
    final top = List<Map<String, dynamic>>.from(
        await topQuery.order('top_until', ascending: false).limit(6));

    var query = Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active');
    if (city != null) query = query.eq('city', city);
    if (top.isNotEmpty) {
      final topIds = top.map((e) => e['id'] as String).join(',');
      query = query.not('id', 'in', '($topIds)');
    }
    final rows = await query.order('created_at', ascending: false).limit(20);
    return [...top, ...List<Map<String, dynamic>>.from(rows)];
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final rows = await Supabase.instance.client
        .from('categories')
        .select('id, slug, name_ru, name_tj')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() {
      _listings = _loadListings();
      _categories = _loadCategories();
    });
    try {
      await _listings;
    } catch (_) {
      // Ошибку покажет FutureBuilder.
    }
  }

  void _openAll() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllCategoriesScreen()));
  }

  void _openSearch() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  /// Нажали на значок TOP: одно окно с выбором объявления и срока продвижения.
  void _openTopSheet() => showTopPickSheet(context);

  void _openCategory(int id, String name, {bool carFilter = false}) {
    Navigator.of(context).push(
      fadeRoute(ListingsScreen(categoryId: id, title: name, carFilter: carFilter)),
    );
  }

  IconData _iconFor(String slug) {
    switch (slug) {
      case 'auto':
        return Icons.directions_car_rounded;
      case 'real-estate':
        return Icons.home_rounded;
      case 'electronics':
        return Icons.smartphone_rounded;
      case 'home':
        return Icons.chair_rounded;
      case 'services':
        return Icons.handyman_rounded;
      case 'jobs':
        return Icons.work_rounded;
      case 'parts':
        return Icons.build_circle_rounded;
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'travel':
        return Icons.luggage_rounded;
      case 'hobby':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  // Размеры плиток из макета: у коротких названий уже, у длинных шире.
  static const _tileWidths = {
    'all': 82.0,
    'real-estate': 139.0,
    'jobs': 139.0,
    'auto': 82.0,
    'electronics': 82.0,
    'services': 82.0,
    'home': 136.0,
  };
  static const _tileLabels = {
    'electronics': 'Элек-\nтроника',
    'jobs': 'Работа и\nподработка',
  };
  static const _tgTileLabels = {
    'electronics': 'Электро-\nника',
    'jobs': 'Кор ва\nмузднон',
  };

  /// 3D-иконки категорий. Пока есть не для всех: остальные показываем Material-иконкой.
  String? _imageFor(String slug) {
    switch (slug) {
      case 'auto':
        return 'assets/icons/auto.png';
      case 'real-estate':
        return 'assets/icons/realestate.png';
      case 'electronics':
        return 'assets/icons/phone.png';
      case 'home':
        return 'assets/icons/home.png';
      case 'services':
        return 'assets/icons/services.png';
      case 'jobs':
        return 'assets/icons/jobs.png';
      case 'parts':
        return 'assets/icons/parts.png';
      case 'fashion':
        return 'assets/icons/fashion.png';
      case 'business':
        return 'assets/icons/business.png';
      case 'travel':
        return 'assets/icons/travel.png';
      case 'hobby':
        return 'assets/icons/hobby.png';
      default:
        return null;
    }
  }

  /// Цвет свечения за 3D-иконкой плитки.
  Color _glowFor(String slug) {
    switch (slug) {
      case 'real-estate':
        return const Color(0xFFFF3B3B); // красный, как крыша дома
      case 'jobs':
        return const Color(0xFFFFB300); // жёлтый, как каска
      case 'auto':
        return const Color(0xFF2D8CFF); // синий
      case 'electronics':
        return const Color(0xFF00C2D1); // бирюзовый
      case 'services':
        return const Color(0xFFFF6A1A); // оранжевый
      case 'home':
        return const Color(0xFFA56BFF); // фиолетовый
      default:
        return AppColors.primary; // зелёный
    }
  }

  Color _accentFor(String slug) {
    switch (slug) {
      case 'jobs':
      case 'services':
        return AppColors.saffron;
      case 'electronics':
        return AppColors.ink;
      default:
        return AppColors.primary;
    }
  }

  Widget _categoryTile(_Cat cat) {
    final isAll = cat.data == null;
    final slug = isAll ? 'all' : cat.data!['slug'] as String;
    return SizedBox(
      width: _tileWidths[slug] ?? 113.0,
      height: 92,
      child: _CategoryChip(
        icon: cat.icon,
        image: cat.image,
        accent: _accentFor(slug),
        glow: _glowFor(slug),
        name: (tajikLang.value ? _tgTileLabels : _tileLabels)[slug] ?? cat.name,
        onTap: isAll
            ? _openAll
            : () => _openCategory(cat.data!['id'] as int, cat.name, carFilter: slug == 'auto'),
      ),
    );
  }

  // Два ряда плиток в одной горизонтальной прокрутке, ряды не выровнены друг по другу.
  Widget _categoryRows(List<Map<String, dynamic>> items) {
    final bySlug = {for (final c in items) c['slug'] as String: c};
    _Cat? catFor(String slug) {
      final c = bySlug[slug];
      return c == null ? null : _Cat(_catName(c), _iconFor(slug), c, image: _imageFor(slug));
    }

    const first = ['real-estate', 'jobs'];
    const second = ['auto', 'electronics', 'services', 'home'];
    final row1 = <_Cat>[_Cat(tr('Все', 'Ҳама'), Icons.grid_view_rounded, null, image: 'assets/icons/all.png')];
    final row2 = <_Cat>[];
    for (final s in first) {
      final c = catFor(s);
      if (c != null) row1.add(c);
    }
    for (final s in second) {
      final c = catFor(s);
      if (c != null) row2.add(c);
    }
    var toRow2 = row2.length <= row1.length;
    for (final c in items) {
      final slug = c['slug'] as String;
      if (first.contains(slug) || second.contains(slug)) continue;
      (toRow2 ? row2 : row1).add(_Cat(_catName(c), _iconFor(slug), c, image: _imageFor(slug)));
      toRow2 = !toRow2;
    }

    Widget row(List<_Cat> cats) => Row(
          children: [
            for (var i = 0; i < cats.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              _categoryTile(cats[i]),
            ],
          ],
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(row1),
          const SizedBox(height: 8),
          row(row2),
        ],
      ),
    );
  }

  /// Шапка главной: при прокрутке зелёная карточка с городом и баннером уезжает,
  /// строка поиска остаётся закреплённой вверху. t: 0 — раскрыта, 1 — свёрнута.
  Widget _homeHeader(double t) {
    final shown = 1 - t;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        children: [
          Positioned(
            left: 11,
            right: 11,
            top: 8,
            bottom: 10,
            child: Opacity(
              opacity: shown,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.deep, AppColors.primary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const HeaderArt(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8 + 8 * shown, 20, 8 + 10 * shown),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: shown,
                    child: Opacity(opacity: shown, child: const _CityButton()),
                  ),
                ),
                SizedBox(height: 8 * shown),
                _SearchField(onTap: _openSearch),
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: shown,
                    child: Opacity(
                      opacity: shown,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                InkWell(
                  onTap: () => tabIndex.value = 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Text(
                          tr('Поднимите объявление в топ', 'Эълонро дар боло баланд кунед'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 4),
                        _TopBadge(onTap: _openTopSheet),
                      ],
                    ),
                  ),
                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HomeHeaderDelegate(builder: _homeHeader),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
            const SizedBox(height: 4),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _categories,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(tr('Не удалось загрузить категории', 'Категорияҳоро боргирӣ карда натавонистем'));
                }
                return _categoryRows(snapshot.data ?? []);
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _listings,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text(tr('Не удалось загрузить объявления', 'Эълонҳоро боргирӣ карда натавонистем')),
                      const SizedBox(height: 8),
                      GreenButton(
                        onPressed: () => setState(() => _listings = _loadListings()),
                        child: Text(tr('Повторить', 'Такрор')),
                      ),
                    ],
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(tr('Объявлений пока нет', 'Ҳоло эълон нест'))),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.66,
                    children: [for (final item in items) ListingCard(item: item)],
                  ),
                );
              },
            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  static const _words = ['работу', 'самокат', 'квартиру', 'телефон', 'даром', 'уборщицу'];
  static const _tgWords = ['корро', 'скутерро', 'хонаро', 'телефонро', 'ройгонро', 'фаррошро'];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _words.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      radius: 26,
      child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Image.asset('assets/logo.png', width: 28, height: 28),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: Align(
                    key: ValueKey(_i),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('Найти ${_words[_i]}', 'Ёфтани ${_tgWords[_i]}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const Icon(Icons.tune_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Кнопка выбора города над поиском: показывает текущий город, по нажатию открывает список.
class _CityButton extends StatelessWidget {
  const _CityButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedCity,
      builder: (context, city, _) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: AppColors.surface24,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showCityPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      city ?? tr('Все города', 'Ҳама шаҳрҳо'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Cat {
  const _Cat(this.name, this.icon, this.data, {this.image});

  final String name;
  final IconData icon;
  final Map<String, dynamic>? data;
  final String? image;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.accent,
    this.glow = AppColors.primary,
    required this.name,
    required this.onTap,
    this.image,
  });

  final IconData icon;
  final String? image;
  final Color accent;
  final Color glow;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      // Зелёное свечение вокруг плитки и тонкая светящаяся рамка.
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Название сверху, иконка — в своей строке внизу справа: текст и иконка не перекрываются.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: image == null
                    ? Icon(icon, color: accent, size: 34)
                    : SizedBox(
                        width: 58,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Цветное свечение за иконкой.
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [glow.withValues(alpha: 0.55), glow.withValues(alpha: 0)],
                                ),
                              ),
                            ),
                            Image.asset(image!, width: 40, height: 40, fit: BoxFit.contain),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Закреплённая шапка: сворачивается при прокрутке от полной высоты до строки поиска.
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeHeaderDelegate({required this.builder});

  final Widget Function(double t) builder;

  static const double _min = 72;
  static const double _max = 200;

  @override
  double get minExtent => _min;

  @override
  double get maxExtent => _max;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final t = (shrinkOffset / (_max - _min)).clamp(0.0, 1.0);
    return builder(t);
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) => true;
}

/// Значок TOP с переливом: золотой блик медленно проходит по нему.
class _TopBadge extends StatefulWidget {
  const _TopBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TopBadge> createState() => _TopBadgeState();
}

class _TopBadgeState extends State<_TopBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Transform.rotate(
        angle: -0.06,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final x = -1 + 2 * _c.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  begin: Alignment(x - 0.7, 0),
                  end: Alignment(x + 0.7, 0),
                  colors: const [Color(0xFFE0A526), Color(0xFFFFE08A), Color(0xFFE0A526)],
                ),
              ),
              child: Text(
                'TOP',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
