import 'package:web/web.dart' as web;

/// Цвет верхней полосы браузера/статус-бара (meta theme-color).
/// В чатах задаём цвет фона чата, чтобы верх экрана не был размытым.
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
