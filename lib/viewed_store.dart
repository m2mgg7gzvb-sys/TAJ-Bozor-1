import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Объявления, которые пользователь уже открывал. Хранятся на устройстве.
class ViewedStore {
  ViewedStore._();

  static final ids = ValueNotifier<Set<String>>({});
  static const _key = 'viewed_listings';

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ids.value = (prefs.getStringList(_key) ?? []).toSet();
    } catch (_) {
      // Без хранилища просто не будет отметок.
    }
  }

  static Future<void> markViewed(String listingId) async {
    if (ids.value.contains(listingId)) return;
    ids.value = {...ids.value, listingId};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, ids.value.toList());
    } catch (_) {}
  }
}
