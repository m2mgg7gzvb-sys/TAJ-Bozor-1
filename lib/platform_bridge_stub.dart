// Заглушка для Android/нативных сборок: браузерных функций здесь нет.
// Звонки и Web Push на Android пока не работают; карта откатывается на OpenStreetMap.

Future<void> agoraJoin(String appId, String channel, String token, int uid) =>
    Future.error(UnsupportedError('Звонки пока не работают в приложении Android'));

Future<void> agoraSetMic(bool on) async {}

Future<void> agoraLeave() async {}

bool agoraIsConnected() => false;

void agoraPrepareAudio() {}

void agoraBackStart() {}

void agoraBackStop() {}

double agoraLevel() => 0;

void ringStart() {}

void ringStop() {}

String tajPushPermission() => 'unsupported';

Future<String> tajPushSubscribe(String publicKey) async => '{"error":"unsupported"}';

bool isOnline() => true;

/// На нативных платформах событий online нет: возвращаем пустую отписку.
void Function() listenOnline(void Function() callback) => () {};

void setBrowserThemeColor(String hex) {}
