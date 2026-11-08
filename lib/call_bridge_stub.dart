// Заглушка звонков для Android: пока работают только в браузере.
Future<void> callJoin(String appId, String channel, String token, int uid) async {
  throw UnsupportedError('Звонки через Интернет пока работают только в браузере');
}

Future<void> callSetMic(bool on) async {}

Future<void> callLeave() async {}

bool callIsConnected() => false;

void ringStart() {}

void ringStop() {}
