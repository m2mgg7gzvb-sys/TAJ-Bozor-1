import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';

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

/// Сколько полных дней TOP ещё действует (0, если TOP не активен).
int topDaysLeft(Map<String, dynamic> item) {
  final until = DateTime.tryParse('${item['top_until'] ?? ''}');
  if (until == null) return 0;
  final left = until.toUtc().difference(DateTime.now().toUtc());
  if (left <= Duration.zero) return 0;
  return (left.inHours / 24).ceil();
}

/// Число дней с правильным окончанием: 1 день, 2 дня, 5 дней.
String daysWord(int n) {
  final m100 = n % 100;
  final m10 = n % 10;
  if (m100 >= 11 && m100 <= 14) return '$n дней';
  if (m10 == 1) return '$n день';
  if (m10 >= 2 && m10 <= 4) return '$n дня';
  return '$n дней';
}

/// Текст подтверждения TOP: сколько уже действует, сколько добавится и итог.
String topExtendLine(int left, int add) {
  if (left <= 0) {
    return tr('TOP будет включён на ${daysWord(add)}', 'TOP $add рӯз фаъол мешавад');
  }
  return tr(
    'У вас действует TOP ${daysWord(left)}, будет продлён на ${daysWord(add)} = ${daysWord(left + add)}',
    'Шумо TOP-и $left рӯз доред, $add рӯз тамдид мешавад = ${left + add} рӯз',
  );
}
