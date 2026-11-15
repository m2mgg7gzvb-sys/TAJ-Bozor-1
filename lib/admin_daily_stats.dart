import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Начало сегодняшнего дня по времени Душанбе (UTC+5), в UTC.
DateTime _startOfTodayDushanbe() {
  final local = DateTime.now().toUtc().add(const Duration(hours: 5));
  return DateTime.utc(local.year, local.month, local.day).subtract(const Duration(hours: 5));
}

/// Карточка «За сегодня»: подано, одобрено, заблокировано.
class AdminDailyStats extends StatefulWidget {
  const AdminDailyStats({super.key});

  @override
  State<AdminDailyStats> createState() => _AdminDailyStatsState();
}

class _AdminDailyStatsState extends State<AdminDailyStats> {
  late Future<(int, int, int)> _future = _load();

  Future<(int, int, int)> _load() async {
    final db = Supabase.instance.client;
    final since = _startOfTodayDushanbe().toIso8601String();
    final submitted = await db.from('listings').select('id').gte('created_at', since);
    final approved = await db
        .from('admin_log')
        .select('id')
        .inFilter('action', ['approve', 'unblock', 'restore'])
        .gte('created_at', since);
    final blocked = await db
        .from('admin_log')
        .select('id')
        .inFilter('action', ['block', 'report_block'])
        .gte('created_at', since);
    return (submitted.length, approved.length, blocked.length);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: FutureBuilder<(int, int, int)>(
        future: _future,
        builder: (context, snap) {
          final s = snap.data;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                _Stat(label: 'Подано', value: s?.$1, color: AppColors.primary),
                _Stat(label: 'Одобрено', value: s?.$2, color: const Color(0xFF2E7D5B)),
                _Stat(label: 'Заблокировано', value: s?.$3, color: const Color(0xFFC0392B)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value == null ? '—' : '$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
