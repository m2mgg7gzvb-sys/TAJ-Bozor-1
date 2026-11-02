import 'package:flutter/material.dart';

import 'fallback_photo.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Страница объявления: галерея, цена, место, продавец, описание и кнопки связи.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what появится в следующей версии')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final photos = photoUrls(item);
    final city = item['city'] as String?;
    final description = item['description'] as String?;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Объявление')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Галерея
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                photos.isEmpty
                    ? SizedBox.expand(child: FallbackPhoto(item: item))
                    : PageView.builder(
                        controller: _pageCtrl,
                        itemCount: photos.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => Image.network(
                          photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.mint),
                        ),
                      ),
                if (photos.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_page + 1} / ${photos.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Цена и название
                Text(
                  priceText(item),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item['title'] as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (city != null && city.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(city, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Продавец
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration(radius: 18),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.mint,
                        child: Icon(Icons.person_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Частное лицо', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            SizedBox(height: 2),
                            Text('Продавец на TAJ Bozor', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Описание
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Описание', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(fontSize: 15, height: 1.5)),
                ],
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),

      // Нижняя панель с кнопками связи
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _soon('Звонок'),
                  child: const Text('Позвонить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.saffron,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: () => _soon('Переписка'),
                  child: const Text('Написать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
