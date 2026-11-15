import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Баланс в TJS и заявки на пополнение. Деньги появятся после подтверждения оплаты.
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _WalletSheet(),
  );
}

class _WalletSheet extends StatefulWidget {
  const _WalletSheet();

  @override
  State<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<_WalletSheet> {
  static const _amounts = [50, 100, 200, 500];
  late Future<(int, List<Map<String, dynamic>>)> _data = _load();
  bool _busy = false;

  Future<(int, List<Map<String, dynamic>>)> _load() async {
    final db = Supabase.instance.client;
    final balance = await db.rpc('get_balance') as int? ?? 0;
    final rows = await db
        .from('wallet_entries')
        .select('amount, kind, status, note, created_at')
        .order('created_at', ascending: false)
        .limit(20);
    return (balance, List<Map<String, dynamic>>.from(rows));
  }

  Future<void> _topup(int amount) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('request_topup', params: {'p_amount': amount});
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('Заявка на $amount TJS создана. Баланс пополнится после подтверждения оплаты.'),
      ));
      setState(() {
        _busy = false;
        _data = _load();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('Не удалось создать заявку. Попробуйте ещё раз.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: FutureBuilder<(int, List<Map<String, dynamic>>)>(
          future: _data,
          builder: (context, snap) {
            final balance = snap.data?.$1 ?? 0;
            final rows = snap.data?.$2 ?? const [];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Баланс', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    snap.connectionState == ConnectionState.waiting ? '…' : '$balance TJS',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  const Text('Пополнить', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in _amounts)
                        OutlinedButton(
                          onPressed: _busy ? null : () => _topup(a),
                          child: Text('$a TJS'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Онлайн-оплата пока не подключена. Заявка появится в истории и пополнит баланс после подтверждения.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text('История', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (snap.connectionState != ConnectionState.waiting && rows.isEmpty)
                    Text('Операций пока нет', style: TextStyle(color: AppColors.muted)),
                  for (final r in rows)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text((r['note'] as String?) ??
                          (r['kind'] == 'topup' ? 'Пополнение' : 'Списание')),
                      subtitle: Text(r['status'] == 'pending' ? 'Ожидает оплаты' : ''),
                      trailing: Text(
                        '${(r['amount'] as num) > 0 ? '+' : ''}${r['amount']} TJS',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: r['status'] == 'pending' ? AppColors.muted : null,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
