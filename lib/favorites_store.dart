import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Избранное текущего пользователя. Хранится в таблице favorites.
class FavoritesStore {
  FavoritesStore._();

  /// Id объявлений, которые пользователь добавил в избранное.
  static final ids = ValueNotifier<Set<String>>({});

  static SupabaseClient get _db => Supabase.instance.client;

  static String? get _uid => _db.auth.currentUser?.id;

  /// Загружает избранное для текущего пользователя (вызывается после входа).
  static Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      ids.value = {};
      return;
    }
    try {
      final rows = await _db.from('favorites').select('listing_id').eq('user_id', uid);
      ids.value = {for (final r in rows) r['listing_id'] as String};
    } catch (_) {
      // Оставляем прежнее состояние, сердечки просто не подсветятся.
    }
  }

  /// Добавляет или убирает объявление из избранного. Возвращает текст ошибки или null.
  static Future<String?> toggle(String listingId) async {
    final uid = _uid;
    if (uid == null) return 'Войдите, чтобы сохранять избранное';
    final wasFav = ids.value.contains(listingId);

    // Сразу показываем новое состояние, при ошибке откатываем.
    final next = Set<String>.from(ids.value);
    if (wasFav) {
      next.remove(listingId);
    } else {
      next.add(listingId);
    }
    ids.value = next;

    try {
      if (wasFav) {
        await _db.from('favorites').delete().eq('user_id', uid).eq('listing_id', listingId);
      } else {
        await _db.from('favorites').insert({'user_id': uid, 'listing_id': listingId});
      }
      return null;
    } catch (_) {
      final rollback = Set<String>.from(ids.value);
      if (wasFav) {
        rollback.add(listingId);
      } else {
        rollback.remove(listingId);
      }
      ids.value = rollback;
      return 'Не удалось сохранить. Проверьте сеть';
    }
  }
}
