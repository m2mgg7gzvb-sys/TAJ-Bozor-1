import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'green_button.dart';
import 'wallet_sheet.dart';

/// Варианты продвижения (TOP): срок в днях и цена в TJS.
const promotePlans = [
  (days: 3, price: 5),
  (days: 7, price: 10),
  (days: 14, price: 18),
  (days: 30, price: 30),
];

/// Окно «TOP»: выбор срока и кнопка оплаты.
/// Онлайн-оплата ещё не подключена, поэтому кнопка пока неактивна.
Future<void> showPromoteSheet(BuildContext context, {required String listingId, required String title}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _PromoteSheet(listingId: listingId, title: title),
  );
}

class _PromoteSheet extends StatefulWidget {
  const _PromoteSheet({required this.listingId, required this.title});

  final String listingId;
  final String title;

  @override
  State<_PromoteSheet> createState() => _PromoteSheetState();
}

class _PromoteSheetState extends State<_PromoteSheet> {
  int _selected = 1; // 7 дней по умолчанию
  int _balance = 0;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final b = await Supabase.instance.client.rpc('get_balance') as int? ?? 0;
      if (mounted) setState(() => _balance = b);
    } catch (_) {
      // Баланс не загрузился: кнопка останется выключенной.
    }
  }

  /// Списывает деньги с баланса и включает TOP для этого объявления.
  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      await Supabase.instance.client.rpc('request_top_orders', params: {
        'p_items': [
          {'listing_id': widget.listingId, 'plan': _selected},
        ],
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('TOP включён. Деньги списаны с баланса.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _paying = false);
      final insufficient = e.toString().contains('insufficient balance');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(insufficient
            ? 'Не хватает денег на балансе. Пополните баланс в профиле.'
            : 'Не удалось включить TOP. Попробуйте ещё раз.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = promotePlans[_selected];
    final enough = plan.price <= _balance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.saffron,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TOP',
                    style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Продвижение объявления', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            const Text(
              'Объявление попадёт в начало списка и будет отмечено как продвигаемое.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < promotePlans.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selected == i ? AppColors.mint : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selected == i ? AppColors.primary : const Color(0xFFE3ECE9),
                        width: _selected == i ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selected == i ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: _selected == i ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${promotePlans[i].days} дней',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                        Text(
                          '${promotePlans[i].price} TJS',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GreenButton(
              onPressed: enough && !_paying ? _pay : null,
              child: Text(_paying
                  ? 'Включаем…'
                  : enough
                      ? 'Оплатить ${plan.price} TJS с баланса'
                      : 'Не хватает ${plan.price - _balance} TJS'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'На балансе: $_balance TJS. Пополнить баланс можно в профиле, в разделе «Баланс и пополнение».',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Окно TOP с главной: отмечаем несколько объявлений, у каждого свой срок, внизу общая цена.
Future<void> showTopPickSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _TopPickSheet(),
  );
}

class _TopPickSheet extends StatefulWidget {
  const _TopPickSheet();

  @override
  State<_TopPickSheet> createState() => _TopPickSheetState();
}

class _TopPickSheetState extends State<_TopPickSheet> {
  late final Future<List<Map<String, dynamic>>> _items = _load();
  // id объявления -> индекс в promotePlans (срок продвижения для этого объявления)
  final Map<String, int> _picks = {};

  bool _submitting = false;
  int _balance = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select('id, title')
        .eq('user_id', uid)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    try {
      _balance = await Supabase.instance.client.rpc('get_balance') as int? ?? 0;
    } catch (_) {
      _balance = 0;
    }
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Сохраняет заявку на TOP. Оплата пока не подключена, поэтому заявка ждёт оплаты.
  Future<void> _submit() async {
    if (_picks.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.rpc('request_top_orders', params: {
        'p_items': [
          for (final e in _picks.entries) {'listing_id': e.key, 'plan': e.value},
        ],
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
        content: Text('TOP включён. Деньги списаны с баланса.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final insufficient = e.toString().contains('insufficient balance');
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(insufficient
            ? 'Не хватает денег на балансе. Пополните баланс в профиле.'
            : 'Не удалось включить TOP. Попробуйте ещё раз.'),
      ));
    }
  }

  int get _total => _picks.values.fold(0, (sum, i) => sum + promotePlans[i].price);

  /// Нажали на объявление: снизу открывается выбор дней для него.
  Future<void> _pickDays(String id, String title) async {
    final result = await showModalBottomSheet<_DaysResult>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DaysPicker(title: title, current: _picks[id]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.remove) {
        _picks.remove(id);
      } else {
        _picks[id] = result.plan!;
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> items) {
    setState(() {
      final allSelected = items.every((e) => _picks.containsKey(e['id'] as String));
      if (allSelected) {
        _picks.clear();
      } else {
        for (final e in items) {
          _picks.putIfAbsent(e['id'] as String, () => 1); // по умолчанию 7 дней
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _items,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final items = snap.data ?? [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.saffron, borderRadius: BorderRadius.circular(8)),
                      child: const Text('TOP',
                          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Продвижение', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () => _selectAll(items),
                        child: Text(
                          items.every((e) => _picks.containsKey(e['id'] as String))
                              ? 'Сбросить'
                              : 'Выбрать все',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Нет активных объявлений', style: TextStyle(color: AppColors.muted)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final id = items[i]['id'] as String;
                        final title = (items[i]['title'] as String?) ?? 'Объявление';
                        final plan = _picks[id];
                        final selected = plan != null;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _pickDays(id, title),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.mint : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? AppColors.primary : const Color(0xFFE3ECE9),
                                  width: selected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                    color: selected ? AppColors.primary : AppColors.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selected
                                        ? '${promotePlans[plan].days} дн · ${promotePlans[plan].price} TJS'
                                        : 'выбрать дни',
                                    style: TextStyle(
                                      color: selected ? AppColors.primary : AppColors.muted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Итого', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$_total TJS',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: GreenButton(
                    onPressed: _picks.isEmpty || _submitting || _total > _balance ? null : _submit,
                    child: Text(_picks.isEmpty
                        ? 'Выберите объявления'
                        : _submitting
                            ? 'Включаем…'
                            : _total > _balance
                                ? 'Не хватает ${_total - _balance} TJS'
                                : 'Оплатить с баланса · $_total TJS'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'На балансе: $_balance TJS. Пополнить баланс можно в профиле, в разделе «Баланс и пополнение».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Результат выбора дней: срок (индекс в promotePlans) или снятие с продвижения.
class _DaysResult {
  const _DaysResult.plan(this.plan) : remove = false;
  const _DaysResult.removed()
      : plan = null,
        remove = true;

  final int? plan;
  final bool remove;
}

/// Нижнее окно выбора дней для одного объявления.
class _DaysPicker extends StatelessWidget {
  const _DaysPicker({required this.title, required this.current});

  final String title;
  final int? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Сколько дней поднимать в TOP', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            for (var i = 0; i < promotePlans.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(_DaysResult.plan(i)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: current == i ? AppColors.mint : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: current == i ? AppColors.primary : const Color(0xFFE3ECE9),
                        width: current == i ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          current == i ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: current == i ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('${promotePlans[i].days} дней',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        ),
                        Text('${promotePlans[i].price} TJS',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            if (current != null)
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(const _DaysResult.removed()),
                  child: const Text('Убрать из продвижения'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
