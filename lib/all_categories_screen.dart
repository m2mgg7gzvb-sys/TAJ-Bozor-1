import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_card.dart';
import 'listing_utils.dart';
import 'listings_screen.dart';
import 'theme.dart';

/// Порядок категорий на экране «Все категории». Категории из базы, которых нет в списке, идут в конец.
const _order = [
  'auto',
  'parts',
  'real-estate',
  'jobs',
  'business',
  'electronics',
  'services',
  'home',
  'fashion',
  'travel',
  'hobby',
];

/// 3D-иконки категорий (те же, что на главной).
String? _imageForSlug(String slug) {
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

IconData _iconForSlug(String slug) {
  switch (slug) {
    case 'auto':
      return Icons.directions_car_rounded;
    case 'parts':
      return Icons.build_circle_rounded;
    case 'real-estate':
      return Icons.home_rounded;
    case 'jobs':
      return Icons.work_rounded;
    case 'business':
      return Icons.business_center_rounded;
    case 'electronics':
      return Icons.smartphone_rounded;
    case 'services':
      return Icons.handyman_rounded;
    case 'home':
      return Icons.chair_rounded;
    case 'fashion':
      return Icons.checkroom_rounded;
    case 'travel':
      return Icons.luggage_rounded;
    case 'hobby':
      return Icons.sports_soccer_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Экран «Все категории»: плитки категорий без заголовков и лента объявлений внизу.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _listingsFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _listingsFuture = _loadListings();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('categories')
        .select('id, slug, name_ru')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Последние активные объявления из всех категорий: выводятся внизу экрана.
  Future<List<Map<String, dynamic>>> _loadListings() async {
    final rows = await Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _open(Map<String, dynamic> c) {
    final slug = c['slug'] as String;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListingsScreen(
          categoryId: c['id'] as int,
          title: c['name_ru'] as String,
          carFilter: slug == 'auto',
        ),
      ),
    );
  }

  /// Плитки идут подряд по две в ряд. Если плиток нечётное число, последняя занимает всю ширину.
  List<Widget> _buildTiles(List<Map<String, dynamic>> items) {
    final bySlug = {for (final c in items) c['slug'] as String: c};
    final ordered = <Map<String, dynamic>>[];
    final used = <String>{};
    for (final s in _order) {
      final c = bySlug[s];
      if (c != null) {
        ordered.add(c);
        used.add(s);
      }
    }
    for (final c in items) {
      if (!used.contains(c['slug'] as String)) ordered.add(c);
    }

    Widget tile(Map<String, dynamic> c) => SizedBox(
          height: 60,
          child: _Tile(cat: c, onTap: () => _open(c)),
        );

    final widgets = <Widget>[];
    for (var i = 0; i < ordered.length; i += 2) {
      final hasSecond = i + 1 < ordered.length;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            Expanded(child: tile(ordered[i])),
            if (hasSecond) ...[
              const SizedBox(width: 8),
              Expanded(child: tile(ordered[i + 1])),
            ],
          ],
        ),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Все категории')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
          return ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ListingsScreen()),
                  ),
                  child: const Text('Все объявления'),
                ),
              ),
              ..._buildTiles(items),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _listingsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Объявлений пока нет', style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.66,
                    children: [for (final item in list) ListingCard(item: item)],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.cat, required this.onTap});

  final Map<String, dynamic> cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slug = cat['slug'] as String;
    final name = cat['name_ru'] as String;
    return Material(
      color: const Color(0xFFEEF1F0),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: AppColors.ink,
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 4,
              child: _imageForSlug(slug) != null
                  ? Image.asset(_imageForSlug(slug)!, width: 32, height: 32, fit: BoxFit.contain)
                  : Icon(_iconForSlug(slug), color: AppColors.primary, size: 26),
            ),
          ],
        ),
      ),
    );
  }
}
