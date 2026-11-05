import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';

/// Центры городов из списка tajCities. Для неизвестного города открываем Душанбе.
const _cityCenters = <String, LatLng>{
  'Душанбе': LatLng(38.5598, 68.7870),
  'Худжанд': LatLng(40.2833, 69.6221),
  'Куляб': LatLng(37.9144, 69.7858),
  'Бохтар': LatLng(37.8386, 68.7756),
  'Турсунзода': LatLng(38.5144, 68.2500),
  'Истаравшан': LatLng(40.1500, 69.0000),
  'Пенджикент': LatLng(39.4900, 67.6100),
  'Исфара': LatLng(40.1000, 70.6000),
  'Кайраккум': LatLng(40.1500, 69.1500),
  'Канибадам': LatLng(40.2700, 70.4000),
  'Гиссар': LatLng(38.5000, 68.6000),
  'Вахдат': LatLng(38.5667, 69.0000),
  'Хорог': LatLng(37.4933, 71.5528),
  'Рогун': LatLng(38.7000, 69.2000),
  'Нурек': LatLng(38.3667, 69.3500),
  'Яван': LatLng(38.0000, 69.0000),
  'Ховалинг': LatLng(37.6000, 69.6000),
};

LatLng _cityCenter(String? city) => _cityCenters[city?.trim()] ?? const LatLng(38.5598, 68.7870);

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
                initialZoom: 13,
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
