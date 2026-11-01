import 'package:flutter/material.dart';

import 'favorites_store.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Карточка объявления для сетки: фото, цена, название, город и сердечко.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.item});

  final Map<String, dynamic> item;

  Future<void> _toggleFav(BuildContext context) async {
    final error = await FavoritesStore.toggle(item['id'] as String);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl(item);
    final city = item['city'] as String?;
    final id = item['id'] as String;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: cardDecoration(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo == null
                      ? const ColoredBox(
                          color: AppColors.mint,
                          child: Center(
                            child: Icon(Icons.image_outlined, size: 36, color: AppColors.primary),
                          ),
                        )
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.mint),
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: FavoritesStore.ids,
                      builder: (context, favIds, _) {
                        final fav = favIds.contains(id);
                        return GestureDetector(
                          onTap: () => _toggleFav(context),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Icon(
                              fav ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: fav ? AppColors.ruby : AppColors.ink,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceText(item),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['title'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (city != null && city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(city, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
