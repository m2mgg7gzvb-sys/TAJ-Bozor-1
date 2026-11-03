import 'search_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'all_categories_screen.dart';
import 'city_store.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'listings_screen.dart';
import 'nav_state.dart';
import 'theme.dart';

/// Главная вкладка «Поиск»: поиск, баннер, категории и новые объявления.
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
    var query = Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active');
    final city = selectedCity.value;
    if (city != null) query = query.eq('city', city);
    final rows = await query.order('created_at', ascending: false).limit(20);
    return List<Map<String, dynamic>>.from(rows);
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

  void _openCategory(int id, String name, {bool carFilter = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListingsScreen(categoryId: id, title: name, carFilter: carFilter),
      ),
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
      height: 78,
      child: _CategoryChip(
        icon: cat.icon,
        accent: _accentFor(slug),
        name: _tileLabels[slug] ?? cat.name,
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
      return c == null ? null : _Cat(c['name_ru'] as String, _iconFor(slug), c);
    }

    const first = ['real-estate', 'jobs'];
    const second = ['auto', 'electronics', 'services', 'home'];
    final row1 = <_Cat>[const _Cat('Все', Icons.grid_view_rounded, null)];
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
      (toRow2 ? row2 : row1).add(_Cat(c['name_ru'] as String, _iconFor(slug), c));
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(11, 8, 11, 10),
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.deep, AppColors.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CityButton(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _SearchField(onTap: _openSearch)),
                    if (Supabase.instance.client.auth.currentUser == null) ...[
                      const SizedBox(width: 10),
                      Material(
                        color: const Color(0xFFF4F6F5),
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: () => tabIndex.value = loginTabIndex,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                            child: Text(
                              'Войти',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => tabIndex.value = 2,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Поднимите объявление в топ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 4),
                        Transform.rotate(
                          angle: -0.06,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.saffron,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text(
                              'ТОП',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
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
                  return const Text('Не удалось загрузить категории');
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
                      const Text('Не удалось загрузить объявления'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => setState(() => _listings = _loadListings()),
                        child: const Text('Повторить'),
                      ),
                    ],
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Объявлений пока нет')),
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
    return Material(
      color: const Color(0xFFF4F6F5),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              SvgPicture.asset('assets/logo.svg', width: 28, height: 28),
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
                      'Найти ${_words[_i]}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const Icon(Icons.tune_rounded, color: AppColors.primary),
            ],
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
            color: Colors.white24,
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
                      city ?? 'Все города',
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
  const _Cat(this.name, this.icon, this.data);

  final String name;
  final IconData icon;
  final Map<String, dynamic>? data;
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
    required this.name,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEEF1F0),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: AppColors.ink,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Icon(icon, color: accent, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}
