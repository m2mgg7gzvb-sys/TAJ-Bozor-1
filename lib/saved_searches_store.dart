import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Сохранённые поиски. Для входа в аккаунт хранятся в базе (таблица saved_searches),
/// без входа — на этом устройстве. Новые — сверху.
class SavedSearchesStore {
  SavedSearchesStore._();

  static const _key = 'saved_searches';

  static final items = ValueNotifier<List<SavedSearch>>([]);

  static bool contains(SavedSearch s) => items.value.any((e) => e.key == s.key);

  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  /// Колонки для поиска по объявлениям (уведомления о новых объявлениях).
  static Map<String, dynamic> _columns(SavedSearch s) {
    final sel = (s.filters?['sel'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final txt = (s.filters?['txt'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    num? price(Object? v) => num.tryParse('${v ?? ''}'.replaceAll(' ', ''));
    return {
      'category_id': s.categoryId,
      'subcategory_id': s.subcategoryId,
      'brand': sel['brand'] as String?,
      'model': sel['model'] as String?,
      'price_min': price(txt['priceMin']),
      'price_max': price(txt['priceMax']),
      'query': s.query,
    };
  }

  /// Загружает список: из базы при входе, иначе из памяти устройства.
  static Future<void> load() async {
    final local = await _loadLocal();
    final uid = _uid;
    if (uid == null) {
      items.value = local;
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('saved_searches')
          .select('payload')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      items.value = [
        for (final r in rows) SavedSearch.fromJson(Map<String, dynamic>.from(r['payload'] as Map)),
      ];
    } catch (_) {
      items.value = local;
    }
  }

  /// Сохраняет поиск, если его нет в списке, иначе убирает.
  static Future<void> toggle(SavedSearch s) async {
    final next = List<SavedSearch>.from(items.value);
    final i = next.indexWhere((e) => e.key == s.key);
    final removing = i >= 0;
    if (removing) {
      next.removeAt(i);
    } else {
      next.insert(0, s);
    }
    items.value = next;

    final uid = _uid;
    if (uid == null) {
      await _saveLocal(next);
      return;
    }
    try {
      if (removing) {
        await Supabase.instance.client
            .from('saved_searches')
            .delete()
            .eq('user_id', uid)
            .eq('key', s.key);
      } else {
        await Supabase.instance.client.from('saved_searches').upsert({
          'user_id': uid,
          'key': s.key,
          'title': s.title,
          'payload': s.toJson(),
          ..._columns(s),
        }, onConflict: 'user_id,key');
      }
    } catch (_) {
      // Не удалось записать в базу: вернём список из базы при следующем открытии.
    }
  }

  static Future<List<SavedSearch>> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      return [for (final r in raw) _parse(r)];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocal(List<SavedSearch> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final e in list) jsonEncode(e.toJson())]);
    } catch (_) {
      // Не критично.
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
