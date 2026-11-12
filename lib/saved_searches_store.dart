import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сохранённый поиск: текст запроса и, если настроены, все фильтры экрана.
class SavedSearch {
  const SavedSearch({
    required this.title,
    this.categoryId,
    this.subcategoryId,
    this.carFilter = false,
    this.query,
    this.filters,
  });

  /// Название в списке.
  final String title;
  final int? categoryId;
  final int? subcategoryId;
  final bool carFilter;

  /// Текст из строки поиска (если поиск был по словам).
  final String? query;

  /// Состояние всех фильтров экрана объявлений.
  final Map<String, dynamic>? filters;

  Map<String, dynamic> toJson() => {
        'title': title,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'carFilter': carFilter,
        'query': query,
        'filters': filters,
      };

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
        title: j['title'] as String? ?? '',
        categoryId: j['categoryId'] as int?,
        subcategoryId: j['subcategoryId'] as int?,
        carFilter: j['carFilter'] as bool? ?? false,
        query: j['query'] as String?,
        filters: (j['filters'] as Map?)?.cast<String, dynamic>(),
      );

  /// Ключ для сравнения: одинаковые поиски имеют одинаковый ключ.
  String get key => jsonEncode(toJson());
}

/// Сохранённые поиски. Хранятся на этом устройстве; новые — сверху.
class SavedSearchesStore {
  SavedSearchesStore._();

  static const _key = 'saved_searches';

  static final items = ValueNotifier<List<SavedSearch>>([]);

  static bool contains(SavedSearch s) => items.value.any((e) => e.key == s.key);

  /// Загружает список из памяти устройства.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      items.value = [for (final r in raw) _parse(r)];
    } catch (_) {
      // Без хранилища список просто останется пустым.
    }
  }

  /// Сохраняет поиск, если его нет в списке, иначе убирает.
  static Future<void> toggle(SavedSearch s) async {
    final next = List<SavedSearch>.from(items.value);
    final i = next.indexWhere((e) => e.key == s.key);
    if (i >= 0) {
      next.removeAt(i);
    } else {
      next.insert(0, s);
    }
    items.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final e in next) jsonEncode(e.toJson())]);
    } catch (_) {
      // Не критично: при следующем открытии список может обновиться.
    }
  }

  /// Старые записи (только текст запроса) читаем как поиск по словам.
  static SavedSearch _parse(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) return SavedSearch.fromJson(j);
    } catch (_) {
      // Не JSON — значит, это старый текстовый запрос.
    }
    return SavedSearch(title: raw, query: raw);
  }
}
