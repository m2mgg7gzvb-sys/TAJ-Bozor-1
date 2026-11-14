import 'package:flutter/material.dart';

import 'theme.dart';

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
            FilledButton(
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
