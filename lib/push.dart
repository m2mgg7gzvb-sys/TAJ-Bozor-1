import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Публичный VAPID-ключ. Его можно хранить в приложении.
/// Приватный ключ хранится только в секретах Supabase и сюда не попадает.
const vapidPublicKey =
    'BNxovT-PVIMCZO6K6AjLO2SG6Im11hb2YDaoAsjwGYPI_Z2Y0f-y_FepIWeRpp55j0aUPQJskyjciXdyKWD2hUw';

@JS('tajPushSubscribe')
external JSPromise<JSString> _tajPushSubscribe(JSString publicKey);

@JS('tajPushPermission')
external JSString _tajPushPermission();

/// Текущее разрешение: 'default', 'granted', 'denied' или 'unsupported'.
String pushPermission() {
  try {
    return _tajPushPermission().toDart;
  } catch (_) {
    return 'unsupported';
  }
}

/// Включает уведомления на этом устройстве. Возвращает null при успехе или текст причины.
/// Вызывать только по нажатию кнопки пользователя.
Future<String?> enablePush() async {
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (me == null) return 'Сначала войдите в аккаунт';

  final raw = (await _tajPushSubscribe(vapidPublicKey.toJS).toDart).toDart;
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final error = data['error'];
  if (error == 'denied') return 'Разрешите уведомления в настройках браузера';
  if (error == 'unsupported') {
    return 'Этот браузер не поддерживает уведомления. Откройте сайт в Chrome или Samsung Internet. На iPhone сначала добавьте сайт на экран «Домой»';
  }
  if (error != null) return 'Не удалось включить уведомления: $error';

  final keys = data['keys'] as Map<String, dynamic>;
  await Supabase.instance.client.from('push_subscriptions').upsert({
    'user_id': me,
    'endpoint': data['endpoint'],
    'p256dh': keys['p256dh'],
    'auth': keys['auth'],
  }, onConflict: 'endpoint');
  return null;
}
