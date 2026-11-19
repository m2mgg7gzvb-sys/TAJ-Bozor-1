// Яндекс-карта только в браузере. На Android подключается заглушка:
// экран выбора адреса сам переходит на OpenStreetMap (через onError).
export 'yandex_map_stub.dart' if (dart.library.js_interop) 'yandex_map_web.dart';
