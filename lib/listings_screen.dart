import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Лента активных объявлений из таблицы listings.
class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('listings')
        .select('id, title, price, currency, city, created_at, listing_images(path, position)')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // Ошибку покажет FutureBuilder.
    }
  }

  /// Публичная ссылка на первое фото объявления (или null, если фото нет).
  String? _photoUrl(Map<String, dynamic> item) {
    final raw = (item['listing_images'] as List?) ?? [];
    final images = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (images.isEmpty) return null;
    images.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    final path = images.first['path'] as String;
    return Supabase.instance.client.storage.from('listing-photos').getPublicUrl(path);
  }

  String _priceText(Map<String, dynamic> item) {
    final price = num.tryParse('${item['price']}');
    if (price == null) return 'Договорная';
    final currency = item['currency'] as String? ?? 'TJS';
    final amount = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return '$amount $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Объявления')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Не удалось загрузить объявления')),
                  const SizedBox(height: 12),
                  Center(
                    child: FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Повторить'),
                    ),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Объявлений пока нет')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) => _ListingTile(
                title: items[i]['title'] as String,
                price: _priceText(items[i]),
                city: items[i]['city'] as String?,
                photoUrl: _photoUrl(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ListingTile extends StatelessWidget {
  const _ListingTile({
    required this.title,
    required this.price,
    required this.city,
    required this.photoUrl,
  });

  final String title;
  final String price;
  final String? city;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photoUrl == null
                ? const ColoredBox(
                    color: AppColors.mint,
                    child: Center(
                      child: Icon(Icons.image_outlined, size: 40, color: AppColors.primary),
                    ),
                  )
                : Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.mint,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.primary),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (city != null && city!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(city!, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
