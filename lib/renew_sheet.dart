import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'green_button.dart';
import 'listing_utils.dart';
import 'promote_sheet.dart';
import 'theme.dart';

/// Окно «Продлить»: срок выбирается так же, как у TOP, но продление бесплатное.
Future<void> showRenewSheet(
  BuildContext context, {
  required Map<String, dynamic> item,
  required VoidCallback onDone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => _RenewSheet(
      item: item,
      onDone: () {
        Navigator.of(sheetCtx).pop();
        onDone();
      },
    ),
  );
}

class _RenewSheet extends StatefulWidget {
  const _RenewSheet({required this.item, required this.onDone});

  final Map<String, dynamic> item;
  final VoidCallback onDone;

  @override
  State<_RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<_RenewSheet> {
  int _selected = 1; // 7 дней по умолчанию, как у TOP
  bool _saving = false;

  /// Добавляет выбранный срок к текущему; без срока — от сегодняшнего дня.
  Future<void> _renew() async {
    if (_saving) return;
    setState(() => _saving = true);
    final days = promotePlans[_selected].days;
    try {
      final now = DateTime.now().toUtc();
      final current = DateTime.tryParse('${widget.item['expires_at'] ?? ''}')?.toUtc();
      final base = current != null && current.isAfter(now) ? current : now;
      final wasExpired = widget.item['status'] == 'expired';
      await Supabase.instance.client.from('listings').update({
        'expires_at': base.add(Duration(days: days)).toIso8601String(),
        'expiry_notified_at': null,
        // Истёкшее объявление снова становится активным (без повторной модерации).
        if (wasExpired) 'status': 'active',
      }).eq('id', widget.item['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Срок продлён на $days дней')));
      widget.onDone();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Не удалось продлить')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = listingDaysLeft(widget.item);
    final title = (widget.item['title'] as String?) ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Продление объявления', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            if (left > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Сейчас до конца срока: ${daysWord(left)}. Новый срок добавится к текущему.',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            for (var i = 0; i < promotePlans.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selected = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _selected == i ? AppColors.mint : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selected == i ? AppColors.primary : AppColors.line,
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
                        const Text('0 TJS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GreenButton(
              onPressed: _saving ? null : _renew,
              child: Text(_saving ? 'Продлеваем…' : 'Продлить на ${promotePlans[_selected].days} дней'),
            ),
          ],
        ),
      ),
    );
  }
}
