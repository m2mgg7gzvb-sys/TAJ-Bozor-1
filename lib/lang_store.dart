import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Язык приложения: false — русский, true — таджикский. Запоминается на телефоне.
final ValueNotifier<bool> tajikLang = ValueNotifier<bool>(false);

Future<void> loadLang() async {
  try {
    final p = await SharedPreferences.getInstance();
    tajikLang.value = p.getString('app_lang') == 'tg';
  } catch (_) {
    // Без сохранённого языка остаётся русский
  }
}

Future<void> setLang(bool tg) async {
  tajikLang.value = tg;
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('app_lang', tg ? 'tg' : 'ru');
  } catch (_) {
    // Не критично: язык останется до перезапуска
  }
}

/// Текст на выбранном языке.
String tr(String ru, String tg) => tajikLang.value ? tg : ru;

/// Нижний лист выбора языка.
void showLanguagePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Язык / Забон', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final opt in const [(false, 'Русский'), (true, 'Тоҷикӣ')])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: tajikLang.value == opt.$1
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  setLang(opt.$1);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
