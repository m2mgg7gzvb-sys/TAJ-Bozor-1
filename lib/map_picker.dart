import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';

/// Центр карты по городу: если город неизвестен, открываем Душанбе.
LatLng _cityCenter(String? city) {
  final c = city ?? '';
  if (c.contains('Худжанд')) return const LatLng(40.2833, 69.6221);
  if (c.contains('Бохтар')) return const LatLng(37.8386, 68.7756);
  if (c.contains('Кулоб')) return const LatLng(37.9144, 69.7858);
  return const LatLng(38.5598, 68.7870);
}

/// Открывает карту, где пользователь ставит точку. Возвращает точку или null, если отменили.
Future<LatLng?> pickMapPoint(BuildContext context, {LatLng? initial, String? city}) {
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(builder: (_) => _MapPickerPage(initial: initial, city: city)),
  );
}

class _MapPickerPage extends StatefulWidget {
  const _MapPickerPage({this.initial, this.city});

  final LatLng? initial;
  final String? city;

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  LatLng? _point;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final center = _point ?? _cityCenter(widget.city);
    return Scaffold(
      appBar: AppBar(title: const Text('Точка на карте')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                onTap: (_, p) => setState(() => _point = p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tajbozor.app',
                ),
                if (_point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _point == null
                      ? 'Нажмите на карту, чтобы поставить точку'
                      : 'Точка выбрана. Можно нажать в другом месте, чтобы передвинуть',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _point == null ? null : () => Navigator.of(context).pop(_point),
                  child: const Text('Готово'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
