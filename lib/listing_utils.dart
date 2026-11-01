import 'package:supabase_flutter/supabase_flutter.dart';

/// Какие поля объявления загружать вместе с фото.
const listingSelect =
    'id, title, description, price, currency, city, created_at, listing_images(path, position)';

/// Публичная ссылка на первое фото объявления (или null).
String? photoUrl(Map<String, dynamic> item) {
  final raw = (item['listing_images'] as List?) ?? [];
  final images = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (images.isEmpty) return null;
  images.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
  final path = images.first['path'] as String;
  return Supabase.instance.client.storage.from('listing-photos').getPublicUrl(path);
}

/// Цена в виде текста, например «1500 TJS».
String priceText(Map<String, dynamic> item) {
  final price = num.tryParse('${item['price']}');
  if (price == null) return 'Договорная';
  final currency = item['currency'] as String? ?? 'TJS';
  final amount = price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
  return '$amount $currency';
}
