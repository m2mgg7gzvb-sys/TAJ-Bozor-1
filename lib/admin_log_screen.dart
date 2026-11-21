import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_log.dart';
import 'theme.dart';

/// Журнал действий администраторов: кто (PR-ID и имя), когда, какое объявление и что изменил.
class AdminLogScreen extends StatefulWidget {
  const AdminLogScreen({super.key});

  @override
  State<AdminLogScreen> createState() => _AdminLogScreenState();
}

class _AdminLogScreenState extends State<AdminLogScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('admin_log')
        .select('created_at, admin_public_id, admin_name, action, listing_public_id, listing_id, from_value, to_value, note')
        .order('created_at', ascending: false)
        .limit(300);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _future = _load());

  String _when(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _change(Map<String, dynamic> r) {
    final action = r['action'] as String? ?? '';
    final name = adminActionNames[action] ?? action;
    final from = r['from_value'] as String?;
    final to = r['to_value'] as String?;
    final note = r['note'] as String?;
    final parts = <String>[name];
    if (from != null || to != null) parts.add('${from ?? '—'} → ${to ?? '—'}');
    if (note != null && note.isNotEmpty) parts.add('Причина: $note');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Журнал админов'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Center(child: Text('Не удалось загрузить журнал'));
            }
            final rows = snap.data ?? const [];
            if (rows.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text('Записей пока нет', style: TextStyle(color: AppColors.muted))),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rows[i];
                final admin = '${r['admin_name'] ?? 'Админ'} · ${r['admin_public_id'] ?? '—'}';
                final listing = r['listing_public_id'] ?? r['listing_id'];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(admin, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_when(r['created_at'] as String?),
                            style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        if (listing != null) ...[
                          const SizedBox(height: 2),
                          Text('Объявление: $listing', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        ],
                        const SizedBox(height: 8),
                        Text(_change(r)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
