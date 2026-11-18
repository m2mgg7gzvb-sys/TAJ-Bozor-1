import 'package:supabase_flutter/supabase_flutter.dart';

/// Контакты для связи в WhatsApp и Telegram (таблица seller_contacts).
/// Сам владелец видит свои значения всегда; собеседник видит их только при show = true.
class SellerContacts {
  const SellerContacts({this.whatsapp, this.telegram, this.show = false});

  /// Номер в формате +992XXXXXXXXX.
  final String? whatsapp;

  /// Ник без @.
  final String? telegram;

  final bool show;

  bool get isEmpty => (whatsapp == null || whatsapp!.isEmpty) && (telegram == null || telegram!.isEmpty);

  /// Ссылка открывает чат с продавцом в WhatsApp.
  Uri? get whatsappUri {
    final n = whatsapp;
    if (n == null || n.isEmpty) return null;
    return Uri.parse('https://wa.me/${n.replaceAll('+', '')}');
  }

  /// Ссылка открывает профиль продавца в Telegram-приложении сразу (запасной вариант — https).
  Uri? get telegramAppUri {
    final t = telegram;
    if (t == null || t.isEmpty) return null;
    return Uri(scheme: 'tg', host: 'resolve', queryParameters: {'domain': t});
  }

  /// Обычная ссылка на профиль: откроется в браузере или приложении, если tg:// не сработал.
  Uri? get telegramUri {
    final t = telegram;
    if (t == null || t.isEmpty) return null;
    return Uri.parse('https://t.me/$t');
  }

  /// Приводит номер к виду +992XXXXXXXXX или +7XXXXXXXXXX. Возвращает null, если формат неверный.
  static String? normalizeWhatsapp(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.isEmpty) return null;
    final ok = RegExp(r'^\+992\d{9}$').hasMatch(cleaned) || RegExp(r'^\+7\d{10}$').hasMatch(cleaned);
    return ok ? cleaned : null;
  }

  /// Принимает @ник, ник или ссылку t.me/ник. Возвращает ник без @ или null.
  static String? normalizeTelegram(String raw) {
    var t = raw.trim();
    t = t.replaceFirst(RegExp(r'^(https?://)?(www\.)?t\.me/'), '');
    t = t.replaceFirst('@', '');
    if (t.isEmpty) return null;
    return RegExp(r'^[A-Za-z][A-Za-z0-9_]{4,31}$').hasMatch(t) ? t : null;
  }

  /// Контакты самого пользователя (для формы профиля). Ошибки глушим: таблица может быть недоступна.
  static Future<SellerContacts> own(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('seller_contacts')
          .select('whatsapp, telegram, show_contacts')
          .eq('user_id', uid)
          .maybeSingle();
      return SellerContacts(
        whatsapp: row?['whatsapp'] as String?,
        telegram: row?['telegram'] as String?,
        show: row?['show_contacts'] == true,
      );
    } catch (_) {
      return const SellerContacts();
    }
  }

  /// Контакты собеседника. Возвращает null, если их нет или владелец не разрешил показ.
  static Future<SellerContacts?> peer(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('seller_contacts')
          .select('whatsapp, telegram, show_contacts')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null || row['show_contacts'] != true) return null;
      final c = SellerContacts(
        whatsapp: row['whatsapp'] as String?,
        telegram: row['telegram'] as String?,
        show: true,
      );
      return c.isEmpty ? null : c;
    } catch (_) {
      return null;
    }
  }

  /// Сохраняет контакты владельца. Значения уже нормализованы.
  static Future<void> save(String uid, {String? whatsapp, String? telegram, required bool show}) async {
    await Supabase.instance.client.from('seller_contacts').upsert({
      'user_id': uid,
      'whatsapp': whatsapp,
      'telegram': telegram,
      'show_contacts': show,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
