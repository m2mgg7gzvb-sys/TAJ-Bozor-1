// Всё, что работает только в браузере (Agora, Web Push, сеть, цвет полосы браузера).
// На Android подключается заглушка platform_bridge_stub.dart, веб — platform_bridge_web.dart.
export 'platform_bridge_stub.dart' if (dart.library.js_interop) 'platform_bridge_web.dart';
