import 'package:flutter/material.dart';

import 'fallback_photo.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Понятные названия характеристик; остальные показываются как есть.
const _labels = <String, String>{
  'brand': 'Марка',
  'model': 'Модель',
  'year': 'Год',
  'mileage_km': 'Пробег, км',
  'engine': 'Двигатель',
  'gearbox': 'Коробка',
  'fuel': 'Топливо',
  'drive': 'Привод',
  'body_type': 'Кузов',
  'rooms': 'Комнат',
  'area': 'Площадь, м²',
  'floor': 'Этаж',
  'ram': 'ОЗУ',
  'storage': 'Память',
  'cpu': 'Процессор',
  'gpu': 'Видеокарта',
  'diagonal': 'Диагональ',
  'condition': 'Состояние',
  'seller_type': 'Продавец',
};

/// Таблица сравнения 2–3 объявлений: цена, город и все заполненные характеристики.
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key, required this.items});

  final List<Map<String, dynamic>> items;

  static String _value(Map<String, dynamic> item, String key) {
    final d = (item['details'] as Map?) ?? const {};
    return '${d[key] ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final keys = <String>{};
    for (final it in items) {
      final d = (it['details'] as Map?) ?? const {};
      for (final k in d.keys) {
        if ('${d[k] ?? ''}'.trim().isNotEmpty) keys.add('$k');
      }
    }
    final rows = <(String, List<String>)>[
      ('Цена', [for (final it in items) priceText(it)]),
      ('Город', [for (final it in items) '${it['city'] ?? '—'}']),
      for (final k in keys)
        (_labels[k] ?? k, [
          for (final it in items) _value(it, k).isEmpty ? '—' : _value(it, k),
        ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Сравнение')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            columnWidths: const {0: FixedColumnWidth(120)},
            defaultColumnWidth: const FixedColumnWidth(160),
            border: const TableBorder(
              horizontalInside: BorderSide(color: AppColors.mint),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  for (final it in items) _header(it),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      child: Text(
                        r.$1,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    for (final v in r.$2)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Text(
                          v,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> it) {
    final photo = photoUrl(it);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 100,
              width: 144,
              child: photo == null
                  ? FallbackPhoto(item: it)
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => FallbackPhoto(item: it),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            it['title'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
