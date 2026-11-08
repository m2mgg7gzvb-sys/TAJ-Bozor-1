// Звонки через Интернет (Agora RTC, только голос). Вызывается из Dart через js_interop.
(function () {
  let client = null;
  let micTrack = null;

  function ensureClient() {
    if (!client) {
      client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' });
      client.on('user-published', async (user, mediaType) => {
        await client.subscribe(user, mediaType);
        if (mediaType === 'audio') user.audioTrack.play();
      });
    }
    return client;
  }

  window.agoraJoin = async function (appId, channel, token, uid) {
    const c = ensureClient();
    await c.join(appId, channel, token, uid);
    micTrack = await AgoraRTC.createMicrophoneAudioTrack();
    await c.publish([micTrack]);
    return true;
  };

  window.agoraSetMic = async function (on) {
    if (micTrack) await micTrack.setEnabled(on);
    return on;
  };

  window.agoraLeave = async function () {
    if (micTrack) {
      micTrack.stop();
      micTrack.close();
      micTrack = null;
    }
    if (client) await client.leave();
    return true;
  };
})();
