import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';
import 'yandex_map_view.dart';

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
  /// Яндекс-карта; если она не открылась, показываем запасную карту OpenStreetMap.
  YandexMapHandle? _yandex;
  final _fallbackController = MapController();
  bool _yandexFailed = false;

  late LatLng _center = widget.initial ?? _cityCenter(widget.city);

  /// Пока адрес не определён, показываем название выбранного города: точка уже стоит в его центре.
  late String _address = (widget.city?.trim().isNotEmpty ?? false) ? widget.city!.trim() : '';
  bool _locating = false;

  /// Яндекс-карта не открылась: переходим на запасную карту в центре выбранного города.
  void _onYandexError() {
    if (!mounted || _yandexFailed) return;
    setState(() {
      _yandexFailed = true;
      _center = _cityCenter(widget.city);
    });
  }

  /// Если человек в этом городе, карта сразу встаёт на его место. Иначе остаётся центр города.
  Future<void> _moveToMe() async {
    if (_locating) return;
    final useFallback = _yandexFailed;
    if (!useFallback && _yandex == null) return;
    setState(() => _locating = true);
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
      _center = me;
      if (useFallback) {
        _fallbackController.move(me, 16);
      } else {
        _yandex?.move(me, zoom: 16);
      }
    } catch (_) {
      // Нет геолокации: остаёмся на центре города
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  Widget _buildMap() {
    if (!_yandexFailed) {
      return YandexMap(
        center: _center,
        zoom: 13,
        picker: true,
        onReady: (map) {
          _yandex = map;
          if (widget.initial == null) _moveToMe();
        },
        onCenter: (point) => _center = point,
        onAddress: (text) {
          // Пустой ответ геокодера не стирает название города.
          if (text.isNotEmpty) setState(() => _address = text);
        },
        onError: _onYandexError,
      );
    }
    return FlutterMap(
      mapController: _fallbackController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 13,
        onPositionChanged: (camera, _) => _center = camera.center,
        onMapReady: () {
          if (widget.initial == null) _moveToMe();
        },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Карта и кнопки разведены по разным областям: иначе встроенная карта перехватывает нажатия на кнопки.
    return Scaffold(
      appBar: AppBar(title: const Text('Точка на карте')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                // Неподвижный маркер по центру: карту двигает пользователь, точка остаётся под маркером.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: const Icon(Icons.location_pin, color: AppColors.primary, size: 44),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.small(
                heroTag: 'locate-me',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                onPressed: _locating ? null : _moveToMe,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Адрес', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _address.isEmpty ? 'Передвигайте карту, чтобы поставить точку' : _address,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
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
