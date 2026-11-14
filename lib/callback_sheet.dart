import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'glass_widgets.dart';
import 'theme.dart';

/// Шторка «Закажите бесплатный звонок»: номер +992, проверка и сохранение заявки.
Future<void> showCallbackSheet(BuildContext context, {required String listingId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GlassSheet(child: _CallbackForm(listingId: listingId)),
  );
}

class _CallbackForm extends StatefulWidget {
  const _CallbackForm({required this.listingId});

  final String listingId;

  @override
  State<_CallbackForm> createState() => _CallbackFormState();
}

class _CallbackFormState extends State<_CallbackForm> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _digits => _ctrl.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _send() async {
    if (_digits.length != 9) {
      setState(() => _error = 'Введите 9 цифр номера, например 90 123 45 67');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('callback_requests').insert({
        'listing_id': widget.listingId,
        'phone': '+992$_digits',
      });
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось отправить заявку. Попробуйте позже');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_done) ...[
            const Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.mint,
                child: Icon(Icons.check_rounded, color: AppColors.primary, size: 34),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('Заявка отправлена', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Менеджер TAJ Bozor свяжется с вами по номеру, который вы указали',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово')),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Закажите бесплатный звонок',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                  child: const Icon(Icons.call_rounded, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Менеджер TAJ Bozor поможет разобраться с предложением и проконсультирует по продавцу и деталям.',
              style: TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('+992', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 12,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '90 123 45 67',
                      filled: true,
                      fillColor: const Color(0xFFF1F4F3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.ruby)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D8CFF)),
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Заказать звонок'),
            ),
          ],
        ],
      ),
    );
  }
}
