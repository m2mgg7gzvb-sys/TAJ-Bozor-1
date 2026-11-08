import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listings_screen.dart';
import 'theme.dart';

/// Разделы для страницы «Все категории». Категории из базы раскладываются по разделам по slug.
/// Категории, которых нет в списке, попадают в раздел «Другое».
const _sections = <String, List<String>>{
  'Транспорт': ['auto', 'parts'],
  'Недвижимость': ['real-estate'],
  'Работа и подработка': ['jobs', 'business'],
  'Электроника': ['electronics'],
  'Услуги': ['services'],
  'Дом и сад': ['home'],
  'Мода и красота': ['fashion'],
  'Путешествия': ['travel'],
  'Хобби и отдых': ['hobby'],
};

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

/// Экран «Все категории»: разделы с плитками, как на макете.
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('categories')
        .select('id, slug, name_ru')
        .order('id');
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

  List<Widget> _buildSections(List<Map<String, dynamic>> items) {
    final bySlug = {for (final c in items) c['slug'] as String: c};
    final used = <String>{};
    final widgets = <Widget>[];

    void addSection(String title, List<Map<String, dynamic>> cats) {
      if (cats.isEmpty) return;
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ));
      widgets.add(GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.9,
        children: [for (final c in cats) _Tile(cat: c, onTap: () => _open(c))],
      ));
    }

    for (final entry in _sections.entries) {
      final cats = <Map<String, dynamic>>[];
      for (final s in entry.value) {
        final c = bySlug[s];
        if (c != null) {
          cats.add(c);
          used.add(s);
        }
      }
      addSection(entry.key, cats);
    }
    final rest = [for (final c in items) if (!used.contains(c['slug'] as String)) c];
    addSection('Другое', rest);
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
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ListingsScreen()),
                  ),
                  child: const Text('Все объявления'),
                ),
              ),
              ..._buildSections(items),
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
