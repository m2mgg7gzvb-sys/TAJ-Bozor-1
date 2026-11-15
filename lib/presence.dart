import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

Timer? _presenceTimer;

/// Отмечаем в базе, что человек в приложении: раз в минуту, пока оно открыто.
/// По этой отметке в чате видно «В сети» и время последнего захода.
void startPresence() {
  _presenceTimer?.cancel();
  _touch();
  _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) => _touch());
}

Future<void> _touch() async {
  if (Supabase.instance.client.auth.currentSession == null) return;
  try {
    await Supabase.instance.client.rpc('touch_last_seen');
  } catch (_) {
    // Не получилось отметить — попробуем в следующую минуту
  }
}
