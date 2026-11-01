import 'package:flutter/material.dart';

import 'listing_utils.dart';
import 'theme.dart';

/// Страница объявления: фото, цена, название, город и описание.
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl(item);
    final city = item['city'] as String?;
    final description = item['description'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Объявление')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: photo == null
                ? const ColoredBox(
                    color: AppColors.mint,
                    child: Center(
                      child: Icon(Icons.image_outlined, size: 48, color: AppColors.primary),
                    ),
                  )
                : Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.mint),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priceText(item),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (city != null && city.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 18, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(city, style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ],
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Описание',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Сообщения появятся в следующей версии')),
            ),
            child: const Text('Написать продавцу'),
          ),
        ),
      ),
    );
  }
}
