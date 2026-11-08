// Звонки на Android: Agora RTC через нативный плагин agora_rtc_engine.
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:record/record.dart';

RtcEngine? _engine;
bool _remoteIn = false;

Future<void> callJoin(String appId, String channel, String token, int uid) async {
  // Запрос доступа к микрофону (тот же запрос, что и у записи голосовых).
  final rec = AudioRecorder();
  final allowed = await rec.hasPermission();
  await rec.dispose();
  if (!allowed) throw Exception('Нет доступа к микрофону. Разрешите его в настройках телефона');

  final engine = createAgoraRtcEngine();
  await engine.initialize(RtcEngineContext(
    appId: appId,
    channelProfile: ChannelProfileType.channelProfileCommunication,
  ));
  engine.registerEventHandler(RtcEngineEventHandler(
    onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
      _remoteIn = true;
    },
    onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
      _remoteIn = false;
    },
  ));
  await engine.enableAudio();
  await engine.joinChannel(
    token: token,
    channelId: channel,
    uid: uid,
    options: const ChannelMediaOptions(
      channelProfile: ChannelProfileType.channelProfileCommunication,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishMicrophoneTrack: true,
      autoSubscribeAudio: true,
    ),
  );
  _engine = engine;
}

Future<void> callSetMic(bool on) async {
  await _engine?.muteLocalAudioStream(!on);
}

Future<void> callLeave() async {
  _remoteIn = false;
  final engine = _engine;
  _engine = null;
  if (engine != null) {
    await engine.leaveChannel();
    await engine.release();
  }
}

bool callIsConnected() => _remoteIn;

// Гудок на Android пока не воспроизводится.
void ringStart() {}

void ringStop() {}
