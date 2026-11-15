import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_utils.dart';
import 'theme.dart';

/// История цены объявления. Показывается, только если цену меняли хотя бы один раз.
class PriceHistoryCard extends StatelessWidget {
  const PriceHistoryCard({super.key, required this.listingId});

  final String listingId;

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('listing_price_history')
        .select('price, changed_at')
        .eq('listing_id', listingId)
        .order('changed_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.length < 2) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'История цены',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _date(r['changed_at'] as String?),
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                        Text(
                          '${groupDigits(num.tryParse('${r['price']}') ?? 0)} TJS',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Старая (более высокая) цена перечёркнута под текущей ценой.
/// Берём последнюю запись истории, где цена была выше текущей.
class OldPriceLine extends StatelessWidget {
  const OldPriceLine({super.key, required this.listingId, required this.price, required this.currency});

  final String listingId;
  final num? price;
  final String currency;

  Future<num?> _load() async {
    final cur = price;
    if (cur == null) return null;
    try {
      final rows = await Supabase.instance.client
          .from('listing_price_history')
          .select('price')
          .eq('listing_id', listingId)
          .gt('price', cur)
          .order('changed_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return null;
      return num.tryParse('${list.first['price']}');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (price == null) return const SizedBox.shrink();
    return FutureBuilder<num?>(
      future: _load(),
      builder: (context, snap) {
        final old = snap.data;
        if (old == null || old <= price!) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${groupDigits(old)} $currency',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
            ),
          ),
        );
      },
    );
  }
}
