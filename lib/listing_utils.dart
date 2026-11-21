import 'package:supabase_flutter/supabase_flutter.dart';

/// Какие поля объявления загружать вместе с фото.
const listingSelect =
    'id, public_id, user_id, lat, lng, title, description, price, currency, city, address, details, created_at, bumped_at, top_until, negotiable, category_id, subcategory_id, listing_images(path, position), categories(slug)';

/// Публичная ссылка на первое фото объявления (или null).
String? photoUrl(Map<String, dynamic> item) {
  final raw = (item['listing_images'] as List?) ?? [];
  final images = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (images.isEmpty) return null;
  images.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
  final path = images.first['path'] as String;
  return Supabase.instance.client.storage.from('listing-photos').getPublicUrl(path);
}

/// Сумма с точками между разрядами: 25000000 → «25.000.000».
String groupDigits(num value) {
  final neg = value < 0;
  final whole = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write('.');
    buf.write(whole[i]);
  }
  return '${neg ? '-' : ''}$buf';
}

/// Цена в виде текста, например «25.000.000 TJS».
String priceText(Map<String, dynamic> item) {
  final price = num.tryParse('${item['price']}');
  if (price == null) return 'Договорная';
  final currency = item['currency'] as String? ?? 'TJS';
  return '${groupDigits(price)} $currency';
}

/// Все фото объявления по порядку (пусто, если фото нет).
List<String> photoUrls(Map<String, dynamic> item) {
  final raw = (item['listing_images'] as List?) ?? [];
  final images = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
  return [
    for (final img in images)
      Supabase.instance.client.storage
          .from('listing-photos')
          .getPublicUrl(img['path'] as String),
  ];
}

/// Добавляет каждой карточке средний рейтинг продавца (`seller_rating`: avg, count).
/// Один запрос на всю страницу; при ошибке карточки просто без рейтинга.
Future<void> attachSellerRatings(List<Map<String, dynamic>> items) async {
  final ids = items.map((e) => e['user_id']).whereType<String>().toSet().toList();
  if (ids.isEmpty) return;
  try {
    final rows = await Supabase.instance.client
        .from('reviews')
        .select('reviewed_id, rating')
        .inFilter('reviewed_id', ids);
    final sum = <String, int>{};
    final cnt = <String, int>{};
    for (final r in rows) {
      final id = r['reviewed_id'] as String?;
      if (id == null) continue;
      sum[id] = (sum[id] ?? 0) + ((r['rating'] as num?)?.toInt() ?? 0);
      cnt[id] = (cnt[id] ?? 0) + 1;
    }
    for (final it in items) {
      final uid = it['user_id'] as String?;
      if (uid == null || cnt[uid] == null) continue;
      it['seller_rating'] = {'avg': sum[uid]! / cnt[uid]!, 'count': cnt[uid]};
    }
  } catch (_) {}
}
