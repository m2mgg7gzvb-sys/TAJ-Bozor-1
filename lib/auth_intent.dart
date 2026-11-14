import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notify_store.dart';

const _intentKey = 'auth_intent';

/// Запоминает перед входом через Apple или Google, входит человек или регистрируется.
Future<void> rememberAuthIntent({required bool register}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_intentKey, register ? 'register' : 'login');
  } catch (_) {
    // Без памяти намерения вход всё равно работает, просто без проверки.
  }
}

/// После входа через Apple или Google: если человек хотел войти, а аккаунта раньше не было,
/// выходим из созданного аккаунта и просим зарегистрироваться.
Future<void> checkAuthIntent(User user) async {
  String? intent;
  try {
    final prefs = await SharedPreferences.getInstance();
    intent = prefs.getString(_intentKey);
    await prefs.remove(_intentKey);
  } catch (_) {
    return;
  }
  if (intent != 'login') return;
  final created = DateTime.tryParse(user.createdAt);
  final isNew = created != null &&
      DateTime.now().toUtc().difference(created.toUtc()) < const Duration(minutes: 3);
  if (!isNew) return;
  await Supabase.instance.client.auth.signOut();
  showTopBanner(
    'Аккаунт не найден',
    'Зарегистрируйтесь через Apple, Google или почту, чтобы войти.',
  );
}
