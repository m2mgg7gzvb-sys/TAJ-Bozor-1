import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lang_store.dart';
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

/// Окно выбора города: белая панель с зелёными волнами по углам, галочка у выбранного города.
Future<void> showCityPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (ctx) {
      final current = selectedCity.value;
      final cities = <String?>[null, ...tajCities];
      return Stack(
        children: [
          // Зелёные волны в углах, как в шапке приложения.
          Positioned(
            top: -70,
            right: -60,
            child: _Glow(size: 200, color: AppColors.primary.withValues(alpha: 0.14)),
          ),
          Positioned(
            bottom: -80,
            left: -70,
            child: _Glow(size: 220, color: AppColors.primary.withValues(alpha: 0.10)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Text(
                      'Выберите город',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.deep),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: cities.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) {
                        final city = cities[i];
                        final selected = city == current;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            city ?? tr('Все города', 'Ҳама шаҳрҳо'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                              color: selected ? AppColors.deep : AppColors.ink,
                            ),
                          ),
                          trailing: AnimatedScale(
                            scale: selected ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          onTap: () {
                            setSelectedCity(city);
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Мягкое зелёное пятно для украшения углов.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
