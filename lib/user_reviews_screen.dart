import 'package:flutter/material.dart';

import 'lang_store.dart';
import 'theme.dart';

/// Все отзывы о пользователе: звёзды и текст, по нажатию из профиля.
class UserReviewsScreen extends StatelessWidget {
  const UserReviewsScreen({super.key, required this.reviews});

  final List<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(tr('Отзывы', 'Бознигариҳо')),
      ),
      body: reviews.isEmpty
          ? Center(
              child: Text(tr('Отзывов пока нет', 'Бознигарӣ ҳанӯз нест'),
                  style: TextStyle(color: AppColors.muted)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in reviews) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= ((r['rating'] as num?)?.toInt() ?? 0)
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                                color: const Color(0xFFF2B600),
                              ),
                          ],
                        ),
                        if ((r['body'] as String?)?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 6),
                          Text(r['body'] as String),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}
