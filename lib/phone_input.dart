import 'package:flutter/services.dart';

/// Ограничивает номер по коду страны: +992 — 9 цифр после кода, +7 — 10 цифр.
/// Лишние цифры не попадают в поле.
class PhoneLimitFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^\d+]'), '');
    // Плюс бывает только в начале
    text = text.startsWith('+') ? '+${text.substring(1).replaceAll('+', '')}' : text.replaceAll('+', '');
    // +7: код и 10 цифр; +992: код и 9 цифр; без кода — как у +992
    final max = text.startsWith('+7') ? 12 : 13;
    if (text.length > max) text = text.substring(0, max);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
