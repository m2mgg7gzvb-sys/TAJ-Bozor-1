import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

/// Яндекс-карта во встроенном фрейме (web/yandex_map.html).
/// В режиме picker сообщает центр карты и адрес после того, как карту перестали двигать.
class YandexMap extends StatefulWidget {
  const YandexMap({
    super.key,
    required this.center,
    this.zoom = 13,
    this.picker = false,
    this.onReady,
    this.onCenter,
    this.onAddress,
    this.onError,
  });

  final LatLng center;
  final double zoom;
  final bool picker;
  final ValueChanged<YandexMapHandle>? onReady;
  final ValueChanged<LatLng>? onCenter;
  final ValueChanged<String>? onAddress;
  final VoidCallback? onError;

  @override
  State<YandexMap> createState() => _YandexMapState();
}

/// Команды карте из Flutter.
class YandexMapHandle {
  YandexMapHandle._(this._frame);

  final web.HTMLIFrameElement _frame;

  void move(LatLng point, {double zoom = 16}) {
    _post({'type': 'move', 'lat': point.latitude, 'lng': point.longitude, 'zoom': zoom});
  }

  void _post(Map<String, Object> message) {
    _frame.contentWindow?.postMessage(jsonEncode(message).toJS, '*'.toJS);
  }
}

class _YandexMapState extends State<YandexMap> {
  static int _counter = 0;

  late final String _viewType = 'yandex-map-${_counter++}';
  late final web.HTMLIFrameElement _frame = web.HTMLIFrameElement()
    ..src = 'yandex_map.html?v=3&lat=${widget.center.latitude}'
        '&lng=${widget.center.longitude}'
        '&zoom=${widget.zoom.round()}'
        '&mode=${widget.picker ? 'picker' : 'view'}'
    ..style.border = '0'
    ..style.width = '100%'
    ..style.height = '100%';

  late final YandexMapHandle _handle = YandexMapHandle._(_frame);
  late final JSFunction _listener = _onMessage.toJS;

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _frame);
    web.window.addEventListener('message', _listener);
  }

  void _onMessage(web.MessageEvent event) {
    // Принимаем сообщения только с нашего сайта (фрейм лежит на том же домене).
    if (event.origin != web.window.location.origin) return;
    final raw = event.data;
    if (raw == null || !raw.isA<JSString>()) return;
    final Map<String, dynamic> data;
    try {
      data = jsonDecode((raw as JSString).toDart) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (data['type']) {
      case 'ready':
        widget.onReady?.call(_handle);
      case 'center':
        widget.onCenter?.call(LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()));
      case 'address':
        widget.onAddress?.call((data['text'] as String?) ?? '');
      case 'error':
        widget.onError?.call();
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
