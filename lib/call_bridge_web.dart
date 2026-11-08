// Звонки в браузере: мост к web/agora.js (Agora Web SDK).
import 'dart:js_interop';

@JS('agoraJoin')
external JSPromise<JSBoolean> _jsJoin(JSString appId, JSString channel, JSString token, JSNumber uid);

@JS('agoraSetMic')
external JSPromise<JSBoolean> _jsSetMic(JSBoolean on);

@JS('agoraLeave')
external JSPromise<JSBoolean> _jsLeave();

@JS('agoraIsConnected')
external JSBoolean _jsIsConnected();

@JS('agoraRingStart')
external void _jsRingStart();

@JS('agoraRingStop')
external void _jsRingStop();

Future<void> callJoin(String appId, String channel, String token, int uid) async {
  await _jsJoin(appId.toJS, channel.toJS, token.toJS, uid.toDouble().toJS).toDart;
}

Future<void> callSetMic(bool on) async {
  await _jsSetMic(on.toJS).toDart;
}

Future<void> callLeave() async {
  await _jsLeave().toDart;
}

bool callIsConnected() => _jsIsConnected().toDart;

void ringStart() {
  try {
    _jsRingStart();
  } catch (_) {}
}

void ringStop() {
  try {
    _jsRingStop();
  } catch (_) {}
}
