import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  Future<List<Map<String, dynamic>>> _loadListings() async {
    final rows = await Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(20);
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListingsScreen()));
  }

  void _openCategory(int id, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingsScreen(categoryId: id, title: name)),
    );
  }

  IconData _iconFor(String slug) {
    switch (slug) {
      case 'auto':
        return Icons.directions_car_rounded;
      case 'real-estate':
        return Icons.apartment_rounded;
      case 'electronics':
        return Icons.devices_rounded;
      case 'home':
        return Icons.chair_rounded;
      case 'services':
        return Icons.handyman_rounded;
      case 'jobs':
        return Icons.work_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDDF0E8), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
                  children: [
                    Expanded(child: _SearchField(onTap: _openAll)),
                    if (Supabase.instance.client.auth.currentUser == null) ...[
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => tabIndex.value = loginTabIndex,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            child: Text(
                              'Войти',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
            const SizedBox(height: 16),
            const _SectionTitle('Категории'),
            const SizedBox(height: 12),
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
                final items = snapshot.data ?? [];
                return SizedBox(
                  height: 148,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    itemCount: items.length + 1,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.85,
                    ),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _CategoryChip(
                          index: 0,
                          icon: Icons.apps_rounded,
                          name: 'Все',
                          onTap: _openAll,
                        );
                      }
                      final c = items[i - 1];
                      return _CategoryChip(
                        index: i,
                        icon: _iconFor(c['slug'] as String),
                        name: c['name_ru'] as String,
                        onTap: () => _openCategory(c['id'] as int, c['name_ru'] as String),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Новые объявления')),
                TextButton(onPressed: _openAll, child: const Text('Все')),
              ],
            ),
            const SizedBox(height: 12),
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
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                  children: [for (final item in items) ListingCard(item: item)],
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    required this.index,
    required this.icon,
    required this.name,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String name;
  final VoidCallback onTap;

  static const _tints = [
    Color(0xFFE3F2EC),
    Color(0xFFFFF3D1),
    Color(0xFFE2EEFF),
    Color(0xFFFDE7EF),
    Color(0xFFEDE7FF),
    Color(0xFFE0F5F5),
  ];
  static const _accents = [
    Color(0xFF0B7A5A),
    Color(0xFFB7850A),
    Color(0xFF2D6FD1),
    Color(0xFFD62D4A),
    Color(0xFF6B4FD1),
    Color(0xFF13807A),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[index % _tints.length];
    final accent = _accents[index % _accents.length];
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
