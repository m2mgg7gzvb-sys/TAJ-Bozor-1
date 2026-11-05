import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_log.dart';
import 'chat_screen.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
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
    // Основной запрос не трогает колонку заявителя: список жалоб грузится в любом случае.
    final rows = List<Map<String, dynamic>>.from(await _db
        .from('listing_reports')
        .select('id, reason, created_at, listing_id, listings(id, title, status, price, currency)')
        .eq('status', 'open')
        .order('created_at', ascending: false));
    if (rows.isEmpty) return rows;
    try {
      // Заявители отдельным запросом; если его не выполнить, карточки покажем без имени.
      final who = List<Map<String, dynamic>>.from(await _db
          .from('listing_reports')
          .select('id, reporter_id')
          .inFilter('id', [for (final r in rows) r['id']]));
      final reporterOf = {for (final w in who) w['id'] as String: w['reporter_id'] as String?};
      for (final r in rows) {
        r['reporter_id'] = reporterOf[r['id'] as String];
      }
      final ids = {for (final r in rows) if (r['reporter_id'] != null) r['reporter_id'] as String};
      if (ids.isNotEmpty) {
        final ps = List<Map<String, dynamic>>.from(
            await _db.from('profiles').select('id, name').inFilter('id', ids.toList()));
        final byId = {for (final p in ps) p['id'] as String: p};
        for (final r in rows) {
          final rid = r['reporter_id'] as String?;
          if (rid != null) r['reporter'] = byId[rid];
        }
      }
    } catch (_) {
      // Без заявителей жалобы всё равно показываем
    }
    return rows;
  }

  void _reload() => setState(() => _future = _load());

  /// Открывает объявление, на которое пожаловались, так, как его видит покупатель.
  Future<void> _viewListing(Map<String, dynamic> report) async {
    final listingId = report['listing_id'] as String?;
    if (listingId == null) return;
    try {
      final row = await _db.from('listings').select('$listingSelect, status').eq('id', listingId).single();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: Map<String, dynamic>.from(row))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление удалено или недоступно')),
        );
      }
    }
  }

  /// Открывает переписку поддержки с тем, кто отправил жалобу. Если она уже есть, открываем её.
  Future<void> _writeReporter(Map<String, dynamic> report) async {
    final reporterId = report['reporter_id'] as String?;
    if (reporterId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final found = await _db
          .from('conversations')
          .select('id')
          .eq('kind', 'support')
          .eq('buyer_id', reporterId)
          .limit(1);
      final String id;
      if (found.isNotEmpty) {
        id = found.first['id'] as String;
      } else {
        final created = await _db
            .from('conversations')
            .insert({'kind': 'support', 'buyer_id': reporterId})
            .select('id')
            .single();
        id = created['id'] as String;
      }
      if (!mounted) return;
      final name = ((report['reporter'] as Map?)?['name'] as String?) ?? 'Заявитель';
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: name)),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть чат с заявителем')));
    }
  }

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
                Padding(padding: const EdgeInsets.all(24), child: Text('Не удалось загрузить жалобы: ${snap.error}', textAlign: TextAlign.center)),
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
                        const SizedBox(height: 4),
                        Text(
                          'Заявитель: ${((r['reporter'] as Map?)?['name'] as String?)?.trim().isNotEmpty == true ? (r['reporter'] as Map)['name'] : 'неизвестно'}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(onPressed: () => _viewListing(r), child: const Text('Просмотреть объявление')),
                            FilledButton(onPressed: () => _blockListing(r), child: const Text('Заблокировать')),
                            OutlinedButton(onPressed: () => _writeReporter(r), child: const Text('Написать заявителю')),
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
