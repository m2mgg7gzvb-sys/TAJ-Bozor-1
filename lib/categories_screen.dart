import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listings_screen.dart';
import 'theme.dart';

/// Главный экран: баннер «Все объявления» и плитки категорий из таблицы categories.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('categories')
        .select('slug, name_ru, name_tj')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
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

  void _openListings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TAJBozor'),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout_rounded), tooltip: 'Выйти'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _future = _load()),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Banner(onTap: _openListings),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                'Категории',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Text('Не удалось загрузить категории'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _future = _load()),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('Категорий пока нет'));
                }
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    for (final c in items)
                      _CategoryTile(
                        icon: _iconFor(c['slug'] as String),
                        nameRu: c['name_ru'] as String,
                        nameTj: (c['name_tj'] as String?) ?? '',
                        onTap: _openListings,
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

class _Banner extends StatelessWidget {
  const _Banner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.deep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Все объявления',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Свежие предложения по всему Таджикистану',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.saffron,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.nameRu,
    required this.nameTj,
    required this.onTap,
  });

  final IconData icon;
  final String nameRu;
  final String nameTj;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nameRu, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (nameTj.isNotEmpty)
                    Text(nameTj, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
