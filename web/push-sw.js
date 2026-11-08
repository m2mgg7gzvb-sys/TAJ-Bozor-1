// Service worker для push-уведомлений. Регистрируется из push.js.
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }
  const title = data.title || 'TAJ Bozor';
  const isCall = title === 'Входящий звонок' || /звонит вам/.test(data.body || '');
  const options = {
    body: data.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data: { url: data.url || '/' },
  };
  if (isCall) {
    // Звонок: не исчезает, пока его не нажмут, и вибрирует (Android).
    options.requireInteraction = true;
    options.vibrate = [400, 200, 400, 200, 400, 200, 400];
    options.tag = 'incoming-call';
    options.renotify = true;
  }
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) return client.focus();
      }
      return self.clients.openWindow(url);
    })
  );
});
