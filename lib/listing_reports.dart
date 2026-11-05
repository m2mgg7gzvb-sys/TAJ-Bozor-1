import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_log.dart';
import 'theme.dart';

const _reportReasons = ['Мошенничество', 'Запрещённый товар', 'Неверная информация', 'Другое'];

/// Окно жалобы на объявление (для любого вошедшего пользователя, кроме владельца).
Future<void> showReportDialog(BuildContext context, String listingId) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Пожаловаться на объявление'),
      children: [
        for (final r in _reportReasons)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, r),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(r)),
          ),
      ],
    ),
  );
  if (reason == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Supabase.instance.client.from('listing_reports').insert({
      'listing_id': listingId,
      'reason': reason,
    });
    messenger.showSnackBar(const SnackBar(content: Text('Спасибо, жалоба отправлена администрации')));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Не удалось отправить жалобу')));
  }
}

/// Жалобы для админов: открытые жалобы, блокировка объявления или закрытие жалобы.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db
        .from('listing_reports')
        .select('id, reason, created_at, listing_id, listings(id, title, status, price, currency)')
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _closeReport(String reportId) async {
    await _db.from('listing_reports').update({'status': 'closed'}).eq('id', reportId);
  }

  Future<void> _blockListing(Map<String, dynamic> report) async {
    final listingId = report['listing_id'] as String;
    final note = await askReason(context, 'Причина блокировки');
    if (note == null) return;
    try {
      await adminSetStatus(
        listingId: listingId,
        status: 'blocked',
        action: 'report_block',
        note: note.isEmpty ? null : note,
      );
      await _closeReport(report['id'] as String);
      _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Объявление заблокировано')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось заблокировать')));
    }
  }

  Future<void> _dismiss(Map<String, dynamic> report) async {
    try {
      await _closeReport(report['id'] as String);
      await _db.from('admin_log').insert({
        'listing_id': report['listing_id'],
        'action': 'report_closed',
      });
      _reload();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось закрыть жалобу')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Жалобы')),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: const [
                Padding(padding: EdgeInsets.all(24), child: Text('Не удалось загрузить жалобы', textAlign: TextAlign.center)),
              ]);
            }
            final items = snap.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(padding: EdgeInsets.all(24), child: Text('Открытых жалоб нет', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in items) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(radius: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((r['reason'] as String?) ?? '', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          ((r['listings'] as Map?)?['title'] as String?) ?? 'Объявление удалено',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(onPressed: () => _blockListing(r), child: const Text('Заблокировать')),
                            OutlinedButton(onPressed: () => _dismiss(r), child: const Text('Закрыть жалобу')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
