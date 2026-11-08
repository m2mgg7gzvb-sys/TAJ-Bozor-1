/// Заглушка для Android: веб-уведомления там не используются.
const vapidPublicKey = '';

String pushPermission() => 'unsupported';

Future<String?> enablePush() async => 'Уведомления пока работают только в браузере';
