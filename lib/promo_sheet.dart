import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'green_button.dart';
import 'theme.dart';

/// Шторка «Активировать промокод»: поле ввода и кнопка в фирменном стиле.
Future<void> showPromoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => const _PromoSheet(),
  );
}

class _PromoSheet extends StatefulWidget {
  const _PromoSheet();

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _message(String raw) {
    if (raw.contains('promo expired')) return 'Срок действия промокода истёк';
    if (raw.contains('promo exhausted')) return 'Промокод уже закончился';
    if (raw.contains('promo already used')) return 'Вы уже использовали этот промокод';
    if (raw.contains('promo not found')) return 'Промокод не найден';
    if (raw.contains('not authenticated')) return 'Войдите, чтобы активировать промокод';
    return 'Не удалось активировать. Попробуйте ещё раз';
  }

  Future<void> _activate() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.rpc('redeem_promo', params: {'p_code': code});
      if (!mounted) return;
      final map = Map<String, dynamic>.from(res as Map);
      final value = map['reward_value'];
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('Промокод активирован: +$value TJS на баланс'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Активировать промокод',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Введите код, чтобы получить бонус на баланс.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _activate(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              decoration: InputDecoration(
                hintText: 'Промокод',
                filled: true,
                fillColor: const Color(0xFFF2F7F5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFC0392B), fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: GreenButton(
                onPressed: _busy ? null : _activate,
                child: Text(_busy ? 'Проверяем…' : 'Активировать'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
