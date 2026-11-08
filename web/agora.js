// Звонки через Интернет (Agora RTC, только голос). Вызывается из Dart через js_interop.
(function () {
  let client = null;
  let micTrack = null;
  let remoteConnected = false;

  // Гудок ожидания: 425 Гц, 1 сек звук, 3 сек тишина (как в обычной телефонии).
  let audioCtx = null;
  let ringTimer = null;

  function playBeep() {
    if (!audioCtx) return;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.frequency.value = 425;
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    const now = audioCtx.currentTime;
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.setValueAtTime(0.25, now + 0.9);
    gain.gain.linearRampToValueAtTime(0, now + 1);
    osc.start(now);
    osc.stop(now + 1);
  }

  function ringStart() {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch (e) {
      return;
    }
    playBeep();
    if (!ringTimer) ringTimer = setInterval(playBeep, 4000);
  }

  function ringStop() {
    if (ringTimer) {
      clearInterval(ringTimer);
      ringTimer = null;
    }
  }

  // Гудок для входящего звонка (вызывается из Dart).
  window.agoraRingStart = ringStart;
  window.agoraRingStop = ringStop;

  function ensureClient() {
    if (!client) {
      client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' });
      client.on('user-published', async (user, mediaType) => {
        await client.subscribe(user, mediaType);
        if (mediaType === 'audio') {
          user.audioTrack.play();
          remoteConnected = true;
          ringStop();
        }
      });
      client.on('user-left', () => {
        remoteConnected = false;
      });
    }
    return client;
  }

  // SDK грузится модулем в index.html: ждём его появления (до 10 сек).
  function agoraReady() {
    if (window.AgoraRTC) return Promise.resolve();
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error('Agora SDK не загрузился')), 10000);
      window.addEventListener('agora-ready', () => { clearTimeout(t); resolve(); }, { once: true });
    });
  }

  window.agoraJoin = async function (appId, channel, token, uid) {
    await agoraReady();
    const c = ensureClient();
    await c.join(appId, channel, token, uid);
    micTrack = await AgoraRTC.createMicrophoneAudioTrack();
    await c.publish([micTrack]);
    ringStart();
    return true;
  };

  // True, когда собеседник уже в разговоре (его аудио опубликовано).
  window.agoraIsConnected = function () {
    return remoteConnected;
  };

  window.agoraSetMic = async function (on) {
    if (micTrack) await micTrack.setEnabled(on);
    return on;
  };

  window.agoraLeave = async function () {
    ringStop();
    remoteConnected = false;
    if (micTrack) {
      micTrack.stop();
      micTrack.close();
      micTrack = null;
    }
    if (client) await client.leave();
    return true;
  };
})();
