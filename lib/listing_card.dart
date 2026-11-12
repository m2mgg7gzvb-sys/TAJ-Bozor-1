import 'package:flutter/material.dart';

import 'fallback_photo.dart';
import 'favorites_store.dart';
import 'listing_detail_screen.dart';
import 'lang_store.dart';
import 'listing_utils.dart';
import 'theme.dart';
import 'viewed_store.dart';

/// Карточка объявления: большое фото, метка «Просмотрено», название и сердечко,
/// цена, город.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.item});

  final Map<String, dynamic> item;

  Future<void> _toggleFav(BuildContext context) async {
    final error = await FavoritesStore.toggle(item['id'] as String);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _open(BuildContext context) {
    ViewedStore.markViewed(item['id'] as String);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
    );
  }

  /// Главные характеристики из details: комнаты, площадь, год, пробег, память.
  static String _facts(Map<String, dynamic> item) {
    final d = (item['details'] as Map?) ?? const {};
    final parts = <String>[];
    void add(String key, String Function(String v) fmt) {
      final v = '${d[key] ?? ''}'.trim();
      if (v.isNotEmpty) parts.add(fmt(v));
    }

    add('rooms', (v) => v == 'Студия' ? 'Студия' : '$v комн.');
    add('area', (v) => '$v м²');
    add('year', (v) => '$v г.');
    add('mileage_km', (v) => '$v км');
    add('ram', (v) => 'RAM $v');
    add('storage', (v) => v);
    return parts.take(3).join(' · ');
  }

  /// Опубликовано за последние сутки.
  static bool _isNew(Map<String, dynamic> item) {
    final created = DateTime.tryParse('${item['created_at'] ?? ''}');
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created.toUtc()) < const Duration(hours: 24);
  }

  static Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl(item);
    final city = item['city'] as String?;
    final id = item['id'] as String;
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(radius: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo == null
                      ? FallbackPhoto(item: item)
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => FallbackPhoto(item: item),
                        ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: ViewedStore.ids,
                      builder: (context, viewed, _) {
                        if (!viewed.contains(id)) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr('Просмотрено', 'Дидашуда'),
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_isNew(item)) _badge('Новое', const Color(0xFF2E7D5B)),
                        if (item['good_deal'] == true) ...[
                          const SizedBox(height: 4),
                          _badge('Выгодно', const Color(0xFFD9822B)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 38),
                          child: Text(
                            item['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<Set<String>>(
                        valueListenable: FavoritesStore.ids,
                        builder: (context, favIds, _) {
                          final fav = favIds.contains(id);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _toggleFav(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                fav ? Icons.favorite : Icons.favorite_border,
                                size: 24,
                                color: fav ? AppColors.ruby : AppColors.ink,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_facts(item).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _facts(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                  if (city != null && city.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
