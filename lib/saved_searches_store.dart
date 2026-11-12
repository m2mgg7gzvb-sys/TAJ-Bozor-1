import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сохранённые поиски. Хранятся на этом устройстве; новые — сверху.
class SavedSearchesStore {
  SavedSearchesStore._();

  static const _key = 'saved_searches';

  /// Текст сохранённых поисков, самый новый первым.
  static final queries = ValueNotifier<List<String>>([]);

  /// Загружает список из памяти устройства.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      queries.value = prefs.getStringList(_key) ?? [];
    } catch (_) {
      // Без хранилища список просто останется пустым.
    }
  }

  /// Сохраняет поиск, если его нет в списке, иначе убирает.
  static Future<void> toggle(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    final next = List<String>.from(queries.value);
    if (next.contains(q)) {
      next.remove(q);
    } else {
      next.insert(0, q);
    }
    queries.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next);
    } catch (_) {
      // Не критично: при следующем открытии список может обновиться.
    }
  }
}
