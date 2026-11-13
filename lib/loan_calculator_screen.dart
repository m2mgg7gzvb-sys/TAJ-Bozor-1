import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Калькулятор рассрочки: первый взнос, срок и ставка → ежемесячный платёж.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key, this.price});

  final num? price;

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  late final TextEditingController _priceCtrl;
  double _downPct = 20; // первый взнос, %
  double _months = 12;
  double _ratePct = 0; // годовая ставка, %

  @override
  void initState() {
    super.initState();
    final p = widget.price;
    _priceCtrl = TextEditingController(text: p == null ? '' : p.round().toString());
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  static String _fmt(num v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf TJS';
  }

  @override
  Widget build(BuildContext context) {
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final down = price * _downPct / 100;
    final principal = price - down;
    final n = _months.round();
    final r = _ratePct / 100 / 12;
    final monthly = price <= 0
        ? 0.0
        : (r == 0 ? principal / n : principal * r / (1 - math.pow(1 + r, -n)));
    final overpay = monthly * n - principal;

    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор рассрочки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Стоимость, TJS'),
          ),
          const SizedBox(height: 16),
          _slider('Первый взнос', '${_downPct.round()}%', _downPct, 0, 80, 16, (v) => setState(() => _downPct = v)),
          _slider('Срок', '${n} мес.', _months, 3, 60, 57, (v) => setState(() => _months = v)),
          _slider('Годовая ставка', '${_ratePct.toStringAsFixed(1)}%', _ratePct, 0, 40, 80, (v) => setState(() => _ratePct = v)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ежемесячный платёж', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  price <= 0 ? '—' : _fmt(monthly),
                  style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _row('Первый взнос', price <= 0 ? '—' : _fmt(down)),
                _row('Сумма кредита', price <= 0 ? '—' : _fmt(principal)),
                _row('Переплата', price <= 0 ? '—' : _fmt(overpay < 0 ? 0 : overpay)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Расчёт ориентировочный. Условия рассрочки у продавца или банка могут отличаться.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, String value, double v, double min, double max, int divisions, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(value: v, min: min, max: max, divisions: divisions, onChanged: onChanged),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(a, style: const TextStyle(color: AppColors.muted))),
            Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
