import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('agoraJoin')
external JSPromise<JSBoolean> _jsJoin(JSString appId, JSString channel, JSString token, JSNumber uid);

@JS('agoraSetMic')
external JSPromise<JSBoolean> _jsSetMic(JSBoolean on);

@JS('agoraLeave')
external JSPromise<JSBoolean> _jsLeave();

@JS('agoraIsConnected')
external JSBoolean _jsIsConnected();

@JS('agoraPrepareAudio')
external void _jsPrepareAudio();

@JS('agoraBackStart')
external void _jsBackStart();

@JS('agoraBackStop')
external void _jsBackStop();

@JS('agoraLevel')
external JSNumber _jsLevel();

@JS('agoraRingStart')
external void _jsRingStart();

@JS('agoraRingStop')
external void _jsRingStop();

@JS('tajPushSubscribe')
external JSPromise<JSString> _tajPushSubscribe(JSString publicKey);

@JS('tajPushPermission')
external JSString _tajPushPermission();

Future<void> agoraJoin(String appId, String channel, String token, int uid) async {
  await _jsJoin(appId.toJS, channel.toJS, token.toJS, uid.toDouble().toJS).toDart;
}

Future<void> agoraSetMic(bool on) async {
  await _jsSetMic(on.toJS).toDart;
}

Future<void> agoraLeave() async {
  await _jsLeave().toDart;
}

bool agoraIsConnected() => _jsIsConnected().toDart;

void agoraPrepareAudio() => _jsPrepareAudio();

void agoraBackStart() => _jsBackStart();

void agoraBackStop() => _jsBackStop();

double agoraLevel() => _jsLevel().toDartDouble;

void ringStart() => _jsRingStart();

void ringStop() => _jsRingStop();

String tajPushPermission() => _tajPushPermission().toDart;

Future<String> tajPushSubscribe(String publicKey) async {
  return (await _tajPushSubscribe(publicKey.toJS).toDart).toDart;
}

bool isOnline() => web.window.navigator.onLine;

/// Подписка на событие «интернет вернулся». Возвращает функцию отписки.
void Function() listenOnline(void Function() callback) {
  void handler(web.Event _) => callback();
  final JSFunction listener = handler.toJS;
  web.window.addEventListener('online', listener);
  return () => web.window.removeEventListener('online', listener);
}

/// Цвет верхней полосы браузера/статус-бара (meta theme-color).
void setBrowserThemeColor(String hex) {
  try {
    final existing = web.document.querySelector('meta[name="theme-color"]');
    if (existing != null) {
      (existing as web.HTMLMetaElement).content = hex;
      return;
    }
    final meta = web.HTMLMetaElement()
      ..name = 'theme-color'
      ..content = hex;
    web.document.head?.append(meta);
  } catch (_) {
    // Не поддерживается браузером — ничего не меняем.
  }
}
