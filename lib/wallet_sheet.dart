import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Баланс в TJS и пополнение. Онлайн-оплата пока не подключена: кнопка создаёт заявку,
/// деньги появятся после подтверждения оплаты.
Future<void> showWalletSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: AppColors.surface,
    builder: (_) => const _WalletSheet(),
  );
}

/// Способы пополнения из макета. Пока только для выбора; сам способ в заявке не сохраняется.
const _methods = [
  ('Visa', 'assets/wallet/visa.png'),
  ('Mastercard', 'assets/wallet/mastercard.png'),
  ('Душанбе Сити', 'assets/payment_icons/dushanbe_city.png'),
  ('Алиф Моби', 'assets/payment_icons/alif_mobi.png'),
  ('Эсхата Онлайн', 'assets/payment_icons/eskhata.png'),
  ('МегаФон Лайф', 'assets/payment_icons/megafon_life.png'),
  ('Хумо Онлайн', 'assets/payment_icons/humo.png'),
];

const _green = Color(0xFF22C55E);

/// Сумма с пробелами между разрядами и копейками: 1250 → «1 250.00».
String _money(int v) {
  final digits = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${v < 0 ? '-' : ''}$buf.00';
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
  bool _hidden = false;
  // Привязанные карты. Пока провайдер не подключён, список пуст: сохранение выключено.
  final List<_LinkedCard> _linked = [];

  String? _assetFor(String name) {
    for (final m in _methods) {
      if (m.$1 == name) return m.$2;
    }
    return null;
  }

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

  Future<void> _openLink(String provider) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _LinkCardSheet(
        provider: provider,
        onLinked: (last4) => setState(() => _linked.add(_LinkedCard(provider, last4))),
      ),
    );
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Фон снизу: волна и силуэт города из макета.
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/wallet/wallet_bg.png',
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: FutureBuilder<(int, List<Map<String, dynamic>>)>(
                future: _data,
                builder: (context, snap) {
                  final loading = snap.connectionState == ConnectionState.waiting;
                  final balance = snap.data?.$1 ?? 0;
                  final rows = snap.data?.$2 ?? const [];
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(onBack: () => Navigator.pop(context)),
                        const SizedBox(height: 18),
                        _BalanceCard(
                          balance: loading ? null : balance,
                          hidden: _hidden,
                          onToggle: () => setState(() => _hidden = !_hidden),
                        ),
                        const SizedBox(height: 26),
                        const _SectionTitle('Пополнение'),
                        const SizedBox(height: 6),
                        Text(
                          'Выберите способ пополнения',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 96,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            children: [
                              for (final m in _methods)
                                _MethodTile(
                                  name: m.$1,
                                  asset: m.$2,
                                  onTap: () => _openLink(m.$1),
                                ),
                              _MethodTile(
                                name: 'Другой',
                                asset: null,
                                onTap: () => _openLink('Другой способ'),
                              ),
                            ],
                          ),
                        ),
                        if (_linked.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 96,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              children: [
                                for (final c in _linked) ...[
                                  _MethodTile(
                                    name: c.provider,
                                    asset: _assetFor(c.provider),
                                    last4: c.last4,
                                    onTap: () => _openLink(c.provider),
                                  ),
                                  // Плитка «ещё такая же карта» рядом с привязанной.
                                  _MethodTile(
                                    name: 'Ещё карта',
                                    asset: null,
                                    onTap: () => _openLink(c.provider),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Онлайн-оплата пока не подключена. Заявка появится в истории и пополнит баланс после подтверждения.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
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
                        // Место под фоновую волну внизу.
                        const SizedBox(height: 110),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedCard {
  const _LinkedCard(this.provider, this.last4);

  final String provider;
  final String last4;
}

class _LinkCardSheet extends StatefulWidget {
  const _LinkCardSheet({required this.provider, this.onLinked});

  final String provider;
  // Вызывается после успешной привязки с последними 4 цифрами карты.
  final void Function(String last4)? onLinked;

  @override
  State<_LinkCardSheet> createState() => _LinkCardSheetState();
}

class _LinkCardSheetState extends State<_LinkCardSheet> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _holder = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Привязать · ${widget.provider}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Номер карты',
                hintText: '0000 0000 0000 0000',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiry,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Срок (ММ/ГГ)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _holder,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Имя на карте'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Сохранение станет доступно после подключения платёжного провайдера. '
              'Номер карты в приложении не хранится: в списке будут только последние 4 цифры.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const FilledButton(
              onPressed: null,
              child: Text('Привязать карту'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: Icon(Icons.chevron_left_rounded, color: AppColors.title, size: 28),
          ),
        ),
        Expanded(
          child: Text(
            'Кошелёк',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.title),
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.hidden, required this.onToggle});

  final int? balance;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = balance == null
        ? '…'
        : hidden
            ? '•••••• TJS'
            : '${_money(balance!)} TJS';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Image.asset('assets/wallet/wallet_crown.png', width: 76, height: 76),
          Container(
            width: 1,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.line,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Баланс',
                  style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: TextStyle(color: AppColors.ink, fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Заголовок раздела: зелёная полоска слева и название.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.name, required this.asset, required this.onTap, this.last4});

  final String name;
  final String? asset;
  final VoidCallback? onTap;
  final String? last4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 86,
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 40,
                width: 64,
                child: asset == null
                    ? Icon(Icons.add_rounded, color: AppColors.primary, size: 30)
                    : Image.asset(asset!, fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Text(
                last4 != null ? '*$last4' : name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: last4 != null ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
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
            '${positive ? '+ ' : '- '}${_money(amount.abs())} TJS',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
