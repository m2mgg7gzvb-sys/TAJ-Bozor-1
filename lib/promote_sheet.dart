import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'green_button.dart';

/// Варианты продвижения (TOP): срок в днях и цена в TJS.
const promotePlans = [
  (days: 3, price: 5),
  (days: 7, price: 10),
  (days: 14, price: 18),
  (days: 30, price: 30),
];

/// Окно «TOP»: выбор срока и кнопка оплаты.
/// Онлайн-оплата ещё не подключена, поэтому кнопка пока неактивна.
Future<void> showPromoteSheet(BuildContext context, {required String title}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _PromoteSheet(title: title),
  );
}

class _PromoteSheet extends StatefulWidget {
  const _PromoteSheet({required this.title});

  final String title;

  @override
  State<_PromoteSheet> createState() => _PromoteSheetState();
}

class _PromoteSheetState extends State<_PromoteSheet> {
  int _selected = 1; // 7 дней по умолчанию

  @override
  Widget build(BuildContext context) {
    final plan = promotePlans[_selected];
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
              onPressed: null,
              child: Text('Оплатить ${plan.price} TJS · скоро'),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Онлайн-оплата пока не подключена. Скоро здесь можно будет оплатить продвижение.',
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

/// Окно TOP с главной: выбор своего активного объявления и срока продвижения в одном окне.
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
  String? _listingId;
  int _plan = 1; // 7 дней по умолчанию

  Future<List<Map<String, dynamic>>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select('id, title')
        .eq('user_id', uid)
        .eq('status', 'active')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final plan = promotePlans[_plan];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SingleChildScrollView(
          child: Column(
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
                ],
              ),
              const SizedBox(height: 18),
              const Text('Выберите объявление',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _items,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Нет активных объявлений',
                          style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final id = items[i]['id'] as String;
                        final selected = _listingId == id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _listingId = id),
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
                                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                    color: selected ? AppColors.primary : AppColors.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      (items[i]['title'] as String?) ?? 'Объявление',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Срок продвижения', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < promotePlans.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == promotePlans.length - 1 ? 0 : 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _plan = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _plan == i ? AppColors.mint : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _plan == i ? AppColors.primary : const Color(0xFFE3ECE9),
                                width: _plan == i ? 1.6 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${promotePlans[i].days} дн.',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${promotePlans[i].price} TJS',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GreenButton(
                  onPressed: null,
                  child: Text(
                    _listingId == null
                        ? 'Выберите объявление'
                        : 'Оплатить ${plan.price} TJS · скоро',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Онлайн-оплата пока не подключена. Скоро здесь можно будет оплатить продвижение.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
