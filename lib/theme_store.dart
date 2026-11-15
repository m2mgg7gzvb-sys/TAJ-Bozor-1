import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Читает выбранную тему из аккаунта (по умолчанию светлая). Без входа — светлая.
Future<void> loadThemeMode() async {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      darkMode.value = false;
      return;
    }
    final row = await Supabase.instance.client
        .from('profiles')
        .select('theme_mode')
        .eq('id', uid)
        .maybeSingle();
    darkMode.value = row?['theme_mode'] == 'dark';
  } catch (_) {
    // Нет связи: остаётся светлая тема.
  }
}

/// Меняет тему сразу и сохраняет выбор в аккаунте.
Future<void> setThemeMode({required bool dark}) async {
  darkMode.value = dark;
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  try {
    await Supabase.instance.client
        .from('profiles')
        .update({'theme_mode': dark ? 'dark' : 'light'})
        .eq('id', uid);
  } catch (_) {
    // Тема уже применена; если сохранить не вышло, при следующем входе вернётся сохранённая.
  }
}
