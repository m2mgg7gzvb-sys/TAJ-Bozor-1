import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Заглушка карты для Android (там карта пока не подключена).
class YandexMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Карта пока доступна только в браузере',
          style: TextStyle(color: Color(0xFF6B7280))),
    );
  }
}

class YandexMapHandle {
  YandexMapHandle._();

  void move(LatLng point, {double zoom = 16}) {}
}
