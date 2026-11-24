import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'green_button.dart';
import 'lang_store.dart';
import 'theme.dart';

/// Кнопка «В кредит» на карточке объявления. Включать, когда подключён банк-партнёр и ставки утверждены.
const bool kCreditEnabled = false;

/// Годовые ставки по валюте, %. ВРЕМЕННЫЕ значения: заменить на условия банка-партнёра до запуска.
const Map<String, double> kCreditRates = {'TJS': 23, 'USD': 15};

/// Сроки кредита, месяцев.
const List<int> kCreditTerms = [12, 24, 36, 48, 60];

/// Заявка на кредит: шаг 1 — условия и расчёт платежа, шаг 2 — контакты и отправка.
class CreditApplicationScreen extends StatefulWidget {
  const CreditApplicationScreen({super.key, required this.price, this.listingId, this.title});

  final num price;
  final String? listingId;
  final String? title;

  @override
  State<CreditApplicationScreen> createState() => _CreditApplicationScreenState();
}

class _CreditApplicationScreenState extends State<CreditApplicationScreen> {
  final _db = Supabase.instance.client;
  final _downCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+992 ');

  String _currency = 'TJS';
  int _term = 12;
  bool _legal = false;
  bool _step2 = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _downCtrl.text = (widget.price * 0.2).round().toString();
  }

  @override
  void dispose() {
    _downCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  double get _down => double.tryParse(_downCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  double get _principal => widget.price - _down;

  /// Ежемесячный платёж по аннуитету.
  double get _monthly {
    final n = _term;
    final r = (kCreditRates[_currency] ?? 0) / 100 / 12;
    if (_principal <= 0) return 0;
    if (r == 0) return _principal / n;
    return _principal * r / (1 - math.pow(1 + r, -n));
  }

  bool get _step1Valid => _down >= 0 && _down < widget.price && _principal > 0;

  static String _fmt(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String get _currencyLabel => _currency == 'USD' ? 'USD' : 'сомони';

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send() async {
    final name = _nameCtrl.text.trim();
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    // Номер: 992 + 9 цифр
    if (name.isEmpty) {
      _snack(tr('Укажите имя', 'Номро ворид кунед'));
      return;
    }
    if (digits.length < 12) {
      _snack(tr('Введите номер телефона полностью', 'Рақами телефонро пурра ворид кунед'));
      return;
    }
    final user = _db.auth.currentUser;
    if (user == null) {
      _snack(tr('Войдите, чтобы отправить заявку', 'Барои фиристодани ариза ворид шавед'));
      return;
    }
    setState(() => _sending = true);
    try {
      await _db.from('credit_applications').insert({
        'user_id': user.id,
        'listing_id': widget.listingId,
        'price': widget.price,
        'currency': _currency,
        'down_payment': _down.round(),
        'term_months': _term,
        'monthly_payment': _monthly.round(),
        'client_name': name,
        'phone': '+$digits',
        'is_legal_entity': _legal,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Заявка отправлена', 'Ариза фиристода шуд')),
          content: Text(tr(
            'Мы передали заявку и свяжемся с вами по номеру телефона.',
            'Ариза фиристода шуд. Мо бо рақами телефон бо шумо тамос мегирем.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _snack(tr('Не удалось отправить заявку, попробуйте позже', 'Фиристодани ариза муяссар нашуд, баъдтар кӯшиш кунед'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Заявка на кредит', 'Ариза барои қарз')),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            if (_step2) {
              setState(() => _step2 = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.title != null && widget.title!.isNotEmpty)
            Text(widget.title!, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          _monthlyCard(),
          const SizedBox(height: 20),
          if (!_step2) ..._step1() else ..._step2Fields(),
        ],
      ),
    );
  }

  Widget _monthlyCard() {
    final showMonthly = _step1Valid;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            showMonthly ? '${_fmt(_monthly)} $_currencyLabel' : '—',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(tr('Ежемесячный платёж', 'Пардохти ҳармоҳа'), style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  List<Widget> _step1() {
    return [
      _label(tr('Валюта кредита', 'Арзи қарз')),
      Row(
        children: [
          for (final c in kCreditRates.keys) ...[
            Expanded(
              child: _choice(
                title: c == 'TJS' ? tr('сомони', 'сомонӣ') : 'USD',
                subtitle: '${kCreditRates[c]!.round()}%',
                selected: _currency == c,
                onTap: () => setState(() => _currency = c),
              ),
            ),
            if (c != kCreditRates.keys.last) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 18),
      _label(tr('Срок кредита', 'Мӯҳлати қарз')),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in kCreditTerms)
            ChoiceChip(
              label: Text('$t ${tr('мес.', 'мо.')}'),
              selected: _term == t,
              onSelected: (_) => setState(() => _term = t),
            ),
        ],
      ),
      const SizedBox(height: 18),
      _label(tr('Первый взнос', 'Пардохти аввал')),
      TextField(
        controller: _downCtrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '0',
          suffixText: _currency == 'USD' ? '\$' : 'с.',
          filled: true,
          fillColor: AppColors.lightFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      if (!_step1Valid && _downCtrl.text.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          tr('Первый взнос должен быть меньше цены', 'Пардохти аввал аз нарх кам бошад'),
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      ],
      const SizedBox(height: 24),
      GreenButton(
        onPressed: _step1Valid ? () => setState(() => _step2 = true) : null,
        child: Text(tr('Продолжить', 'Идома')),
      ),
    ];
  }

  List<Widget> _step2Fields() {
    return [
      _label(tr('Имя клиента', 'Номи муштарӣ')),
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: tr('Например, Рахимова Ситора', 'Масалан, Рахимова Ситора'),
          filled: true,
          fillColor: AppColors.lightFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 14),
      _label(tr('Телефон', 'Телефон')),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.lightFill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 14),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _legal,
        onChanged: (v) => setState(() => _legal = v),
        title: Text(tr('Юридическое лицо', 'Шахси ҳуқуқӣ')),
      ),
      const SizedBox(height: 10),
      Text(
        tr(
          'Отправляя заявку, вы соглашаетесь на передачу её данных банку-партнёру для рассмотрения. Решение о кредите принимает банк.',
          'Бо фиристодани ариза шумо ба додани маълумоти он ба бонки шарикӣ барои баррасӣ розӣ мешавед. Қарорро бонк қабул мекунад.',
        ),
        style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 20),
      GreenButton(
        // Пока банк-партнёр не подключён, отправка выключена.
        onPressed: kCreditEnabled && !_sending ? _send : null,
        child: Text(tr('Подать заявку', 'Ариза пешниҳод кардан')),
      ),
    ];
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _choice({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
