// Карта на Android: OpenStreetMap через flutter_map (Яндекс-карта только в браузере).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

class _YandexMapState extends State<YandexMap> {
  final MapController _controller = MapController();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            onMapReady: () => widget.onReady?.call(YandexMapHandle._(_controller)),
            onMapEvent: (event) {
              if (widget.picker && event is MapEventMoveEnd) {
                widget.onCenter?.call(_controller.camera.center);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tj.tajbozor.app',
            ),
          ],
        ),
        if (widget.picker)
          const IgnorePointer(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(Icons.location_on, size: 40, color: Color(0xFFE53935)),
            ),
          ),
      ],
    );
  }
}

/// Команды карте из Flutter.
class YandexMapHandle {
  YandexMapHandle._(this._controller);

  final MapController _controller;

  void move(LatLng point, {double zoom = 16}) {
    _controller.move(point, zoom);
  }
}
