import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Заглушка Яндекс-карты для Android: сразу сообщает об ошибке, чтобы открылась карта OpenStreetMap.
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
  State<YandexMap> createState() => _YandexMapStubState();
}

/// Команды карте из Flutter (в заглушке ничего не делают).
class YandexMapHandle {
  const YandexMapHandle();

  void move(LatLng point, {double zoom = 16}) {}
}

class _YandexMapStubState extends State<YandexMap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onError?.call();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
