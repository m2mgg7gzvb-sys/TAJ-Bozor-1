// Web Push: регистрация service worker и подписка пользователя на уведомления.
(function () {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('push-sw.js').catch(function () {});
  }

  function urlBase64ToUint8Array(base64) {
    var padding = '='.repeat((4 - (base64.length % 4)) % 4);
    var b64 = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/');
    var raw = atob(b64);
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  // Вызывается по нажатию кнопки (на iOS разрешение спрашивают только по жесту пользователя).
  // Возвращает JSON: подписка или { error: 'denied' | 'unsupported' | текст }.
  window.tajPushSubscribe = async function (publicKey) {
    try {
      if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
        return JSON.stringify({ error: 'unsupported' });
      }
      var permission = await Notification.requestPermission();
      if (permission !== 'granted') return JSON.stringify({ error: 'denied' });
      var reg = await navigator.serviceWorker.ready;
      var sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(publicKey),
        });
      }
      return JSON.stringify(sub.toJSON());
    } catch (e) {
      return JSON.stringify({ error: String(e) });
    }
  };
})();
