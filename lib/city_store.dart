import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Города для выбора и для поля «Город» при подаче объявления.
const tajCities = [
  'Душанбе',
  'Худжанд',
  'Куляб',
  'Бохтар',
  'Турсунзода',
  'Истаравшан',
  'Пенджикент',
  'Исфара',
  'Кайраккум',
  'Канибадам',
  'Гиссар',
  'Вахдат',
  'Хорог',
  'Рогун',
  'Нурек',
  'Яван',
  'Ховалинг',
  'Файзабад',
  'Шахритуз',
  'Дангара',
  'Бустон',
];

/// Выбранный город. null — показываем объявления из всех городов.
final ValueNotifier<String?> selectedCity = ValueNotifier<String?>(null);

const _cityKey = 'selected_city';

/// Читаем город, который человек выбрал раньше.
Future<void> loadSelectedCity() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    selectedCity.value = prefs.getString(_cityKey);
  } catch (_) {
    // Без сохранённого города покажем объявления из всех городов.
  }
}

/// Меняем город и запоминаем выбор на этом телефоне.
Future<void> setSelectedCity(String? city) async {
  selectedCity.value = city;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (city == null) {
      await prefs.remove(_cityKey);
    } else {
      await prefs.setString(_cityKey, city);
    }
  } catch (_) {
    // Не критично: выбор останется до перезапуска приложения.
  }
}

/// Окно выбора города со списком всех городов.
Future<void> showCityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final current = selectedCity.value;
      Widget tick(bool selected) =>
          selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : const SizedBox.shrink();
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Выберите город',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              title: const Text('Все города'),
              trailing: tick(current == null),
              onTap: () {
                setSelectedCity(null);
                Navigator.of(ctx).pop();
              },
            ),
            for (final c in tajCities)
              ListTile(
                title: Text(c),
                trailing: tick(c == current),
                onTap: () {
                  setSelectedCity(c);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}
