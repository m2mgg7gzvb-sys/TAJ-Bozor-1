import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
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
  final _mapController = MapController();
  late LatLng _center = widget.initial ?? _cityCenter(widget.city);

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) _moveToMe();
  }

  /// Если человек в этом городе, карта сразу встаёт на его место. Иначе остаётся центр города.
  Future<void> _moveToMe() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      final city = _cityCenter(widget.city);
      if (const Distance().as(LengthUnit.Kilometer, city, me) < 60) {
        _mapController.move(me, 16);
      }
    } catch (_) {
      // Нет геолокации: остаёмся на центре города
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Точка на карте')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 13,
                    onPositionChanged: (camera, _) => _center = camera.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tajbozor.app',
                    ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                    ),
                  ],
                ),
                // Неподвижный маркер по центру: карту двигает пользователь, точка остаётся под маркером.
                IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: const Icon(Icons.location_pin, color: Colors.red, size: 44),
                  ),
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
                const Text(
                  'Передвигайте карту, чтобы красный маркер стоял на нужном месте',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_center),
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
