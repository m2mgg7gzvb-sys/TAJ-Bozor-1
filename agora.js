// Звонки через Интернет (Agora RTC, только голос). Вызывается из Dart через js_interop.
(function () {
  let client = null;
  let micTrack = null;
  let remoteConnected = false;
  // Удалённые пользователи с опубликованным голосом: их звук нужно запустить снова, если браузер его заблокировал.
  const remoteAudio = new Set();

  function playRemote(user) {
    try {
      if (user.audioTrack) user.audioTrack.play();
    } catch (e) {
      // Браузер не дал играть звук: попробуем снова при следующем касании экрана.
    }
  }

  // Мелодия входящего звонка: два тона, 1.8 сек звучит, 1.7 сек тишина, и так пока не ответят.
  let audioCtx = null;
  let ringTimer = null;
  let vibrateTimer = null;

  function playRingtone() {
    if (!audioCtx) return;
    const now = audioCtx.currentTime;
    [440, 480].forEach((freq) => {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.frequency.value = freq;
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(0.2, now + 0.05);
      gain.gain.setValueAtTime(0.2, now + 1.6);
      gain.gain.linearRampToValueAtTime(0, now + 1.8);
      osc.start(now);
      osc.stop(now + 1.8);
    });
  }

  function vibrateOnce() {
    try {
      if (navigator.vibrate) navigator.vibrate([600, 300, 600, 1300]);
    } catch (e) {
      // Вибрация не поддерживается (например, iPhone в браузере).
    }
  }

  function ringStart() {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch (e) {
      // Звук недоступен: остаётся только вибрация и экран.
    }
    playRingtone();
    if (!ringTimer) ringTimer = setInterval(playRingtone, 3500);
    vibrateOnce();
    if (!vibrateTimer) vibrateTimer = setInterval(vibrateOnce, 3500);
  }

  function ringStop() {
    if (ringTimer) {
      clearInterval(ringTimer);
      ringTimer = null;
    }
    if (vibrateTimer) {
      clearInterval(vibrateTimer);
      vibrateTimer = null;
    }
    try {
      if (navigator.vibrate) navigator.vibrate(0);
    } catch (e) {}
  }

  // Гудок для входящего звонка (вызывается из Dart).
  window.agoraRingStart = ringStart;
  window.agoraRingStop = ringStop;

  // Гудки у звонящего: пока собеседник не ответил. Тон 425 Гц — 1 сек звучит, 3 сек тишина.
  let backTimer = null;

  function playBackTone() {
    if (!audioCtx) return;
    const now = audioCtx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.frequency.value = 425;
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(0.18, now + 0.05);
    gain.gain.setValueAtTime(0.18, now + 0.95);
    gain.gain.linearRampToValueAtTime(0, now + 1.0);
    osc.start(now);
    osc.stop(now + 1.0);
  }

  function backStart() {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch (e) {
      return;
    }
    playBackTone();
    if (!backTimer) backTimer = setInterval(playBackTone, 4000);
  }

  function backStop() {
    if (backTimer) {
      clearInterval(backTimer);
      backTimer = null;
    }
  }

  // Вызывается сразу при нажатии «Позвонить» (в момент касания), чтобы браузер разрешил звук.
  window.agoraPrepareAudio = function () {
    try {
      if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch (e) {}
  };
  window.agoraBackStart = backStart;
  window.agoraBackStop = backStop;

  function ensureClient() {
    if (!client) {
      client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' });
      client.on('user-published', async (user, mediaType) => {
        await client.subscribe(user, mediaType);
        if (mediaType === 'audio') {
          remoteAudio.add(user);
          playRemote(user);
          remoteConnected = true;
          ringStop();
        }
      });
      client.on('user-unpublished', (user, mediaType) => {
        if (mediaType === 'audio') remoteAudio.delete(user);
      });
      client.on('user-left', (user) => {
        remoteAudio.delete(user);
        remoteConnected = false;
      });
      // Safari и iPhone не запускают звук без нажатия: запускаем его при первом касании.
      if (window.AgoraRTC) {
        window.AgoraRTC.onAudioAutoplayFailed = () => {
          const resume = () => {
            remoteAudio.forEach(playRemote);
            document.removeEventListener('click', resume);
            document.removeEventListener('touchend', resume);
          };
          document.addEventListener('click', resume);
          document.addEventListener('touchend', resume);
        };
      }
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
    return true;
  };

  // True, когда собеседник уже в разговоре (его аудио опубликовано).
  window.agoraIsConnected = function () {
    return remoteConnected;
  };

  // Громкость (0..1): самое громкое из нашего микрофона и голоса собеседника. Для анимации линий.
  window.agoraLevel = function () {
    let level = 0;
    try {
      if (micTrack) level = Math.max(level, micTrack.getVolumeLevel() || 0);
      remoteAudio.forEach((u) => {
        if (u.audioTrack) level = Math.max(level, u.audioTrack.getVolumeLevel() || 0);
      });
    } catch (e) {
      // Трек ещё не готов: считаем тишиной.
    }
    return level;
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
