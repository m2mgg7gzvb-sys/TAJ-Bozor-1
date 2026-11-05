import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_screen.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Кружок с буквой имени или фото пользователя.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.radius = 18});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage: hasPhoto ? NetworkImage(url!) : null,
      child: hasPhoto
          ? null
          : Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.9,
              ),
            ),
    );
  }
}

class _UserData {
  const _UserData({required this.profile, required this.listings, required this.reviews});

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> listings;
  final List<Map<String, dynamic>> reviews;

  int get activeCount => listings.where((l) => l['status'] == 'active').length;
  int get closedCount => listings.where((l) => l['status'] != 'active').length;
  double? get avgRating {
    if (reviews.isEmpty) return null;
    final sum = reviews.fold<int>(0, (s, r) => s + ((r['rating'] as num?)?.toInt() ?? 0));
    return sum / reviews.length;
  }
}

/// Публичный профиль пользователя: объявления, статистика и отзывы.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _db = Supabase.instance.client;
  late Future<_UserData> _future = _load();

  String get _me => _db.auth.currentUser?.id ?? '';

  Future<_UserData> _load() async {
    final profile = await _db
        .from('profiles')
        .select('name, city, avatar_url')
        .eq('id', widget.userId)
        .maybeSingle();
    final listings = List<Map<String, dynamic>>.from(await _db
        .from('listings')
        .select('$listingSelect, status')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false));
    final reviews = List<Map<String, dynamic>>.from(await _db
        .from('reviews')
        .select('rating, body, created_at')
        .eq('reviewed_id', widget.userId)
        .order('created_at', ascending: false));
    return _UserData(profile: profile ?? {}, listings: listings, reviews: reviews);
  }

  /// Открывает личную переписку с этим пользователем.
  Future<void> _write(String title) async {
    try {
      final id = await findOrCreateConversation(kind: 'listing', sellerId: widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: title)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть переписку')),
      );
    }
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль пользователя')),
      body: FutureBuilder<_UserData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Не удалось загрузить профиль'));
          }
          final d = snap.data!;
          final name = (d.profile['name'] as String?)?.trim();
          final displayName = (name == null || name.isEmpty) ? 'Пользователь' : name;
          final city = d.profile['city'] as String?;
          final avg = d.avgRating;
          final canReview = _me.isNotEmpty && _me != widget.userId;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: displayName,
                        url: d.profile['avatar_url'] as String?,
                        radius: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            if (city != null && city.isNotEmpty)
                              Text(city, style: const TextStyle(color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canReview) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _write(displayName),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Написать'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('${d.activeCount}', 'Активных'),
                    const SizedBox(width: 10),
                    _stat('${d.closedCount}', 'Завершённых'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat('${d.reviews.length}', 'Отзывов'),
                    const SizedBox(width: 10),
                    _stat(avg == null ? '—' : avg.toStringAsFixed(1), 'Средняя оценка'),
                  ],
                ),
                const SizedBox(height: 22),
                const Text('Объявления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (d.activeCount == 0)
                  const Text('Активных объявлений нет', style: TextStyle(color: AppColors.muted))
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.66,
                    children: [
                      for (final l in d.listings.where((l) => l['status'] == 'active'))
                        ListingCard(item: l),
                    ],
                  ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Отзывы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (d.reviews.isEmpty)
                  const Text('Отзывов пока нет', style: TextStyle(color: AppColors.muted))
                else
                  for (final r in d.reviews) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
        },
      ),
    );
  }
}
