import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Баланс в TJS и пополнение. Онлайн-оплата пока не подключена: кнопка создаёт заявку,
/// деньги появятся после подтверждения оплаты.
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _WalletSheet(),
  );
}

/// Способы пополнения из макета. Пока только для выбора; сам способ в заявке не сохраняется.
const _methods = [
  ('VISA', Color(0xFF1A1F71)),
  ('Mastercard', Color(0xFFEB001B)),
  ('Humo', Color(0xFF0E7C66)),
  ('PayMe', Color(0xFF00B3E6)),
  ('Click', Color(0xFF3DBE29)),
];

const _gold = Color(0xFFF5C84B);
const _green = Color(0xFF22C55E);

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

  Future<void> _pickAmount(String method) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сумма пополнения · $method',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _amounts)
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, a),
                      child: Text('$a TJS'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (amount != null) await _topup(amount, method);
  }

  Future<void> _topup(int amount, String method) async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc('request_topup', params: {'p_amount': amount});
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('Заявка на $amount TJS ($method) создана. Баланс пополнится после подтверждения оплаты.'),
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
            final loading = snap.connectionState == ConnectionState.waiting;
            final balance = snap.data?.$1 ?? 0;
            final rows = snap.data?.$2 ?? const [];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BalanceCard(balance: loading ? null : balance),
                  const SizedBox(height: 22),
                  const _SectionTitle('Пополнение'),
                  const SizedBox(height: 4),
                  Text(
                    'Выберите способ пополнения',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final m in _methods)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _MethodTile(
                              label: m.$1,
                              color: m.$2,
                              onTap: _busy ? null : () => _pickAmount(m.$1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Онлайн-оплата пока не подключена. Заявка появится в истории и пополнит баланс после подтверждения.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('История'),
                  const SizedBox(height: 12),
                  if (!loading && rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Операций пока нет',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          _HistoryRow(row: rows[i]),
                          if (i < rows.length - 1)
                            Divider(height: 1, indent: 62, color: AppColors.line),
                        ],
                      ],
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deep, AppColors.primary],
        ),
        border: Border.all(color: _gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 46, color: _gold),
          Container(
            width: 1,
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Colors.white24,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Баланс',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  balance == null ? '…' : '$balance TJS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.account_balance_wallet_rounded, color: _gold),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: _gold.withValues(alpha: 0.6))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.title,
              )),
        ),
        Expanded(child: Divider(color: _gold.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.7), width: 1.2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row});

  final Map<String, dynamic> row;

  String _date() {
    final raw = row['created_at'] as String?;
    if (raw == null) return '';
    final d = DateTime.parse(raw).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} • ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final amount = (row['amount'] as num).toInt();
    final pending = row['status'] == 'pending';
    final positive = amount > 0;
    final color = pending
        ? AppColors.muted
        : (positive ? _green : AppColors.ruby);
    final title = (row['note'] as String?) ??
        (row['kind'] == 'topup' ? 'Пополнение' : 'Списание');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              positive ? Icons.add_rounded : Icons.remove_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  pending ? 'Ожидает оплаты · ${_date()}' : _date(),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}$amount TJS',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
