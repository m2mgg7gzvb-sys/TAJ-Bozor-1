import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'city_store.dart';
import 'tajikistan_outline.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'theme.dart';

/// Объявления из текущего списка на карте. Нажатие на метку открывает объявление.
class ListingsMapScreen extends StatelessWidget {
  const ListingsMapScreen({super.key, required this.items, required this.title});

  final List<Map<String, dynamic>> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    final placed = items.where((i) => i['lat'] is num && i['lng'] is num).toList();
    // Центр — Душанбе, если у объявлений нет координат.
    final center = placed.isEmpty
        ? const LatLng(38.5358, 68.7791)
        : LatLng((placed.first['lat'] as num).toDouble(), (placed.first['lng'] as num).toDouble());

    return Scaffold(
      appBar: AppBar(title: Text('$title на карте')),
      body: placed.isEmpty
          ? const Center(child: Text('Нет объявлений с координатами на карте'))
          : FlutterMap(
              options: selectedCity.value == null
                  // Город не выбран: показываем всю территорию Таджикистана.
                  ? MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: LatLngBounds(const LatLng(36.67, 67.33), const LatLng(41.05, 75.15)),
                        padding: const EdgeInsets.all(24),
                      ),
                    )
                  : MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tajbozor.app',
                ),
                // Белый фон за пределами Таджикистана, территория страны остаётся картой.
                // Красивый фон за пределами Таджикистана (градиент в стиле приложения).
                Positioned.fill(
                  child: Builder(
                    builder: (context) => CustomPaint(
                      painter: _OutsideBackgroundPainter(MapCamera.of(context), tajikistanOutline, darkMode.value),
                    ),
                  ),
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: [for (final p in tajikistanOutline) LatLng(p[1], p[0])],
                      color: Colors.transparent,
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final it in placed)
                      Marker(
                        point: LatLng((it['lat'] as num).toDouble(), (it['lng'] as num).toDouble()),
                        width: 120,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ListingDetailScreen(item: it)),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: Text(
                              priceText(it),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}


/// Рисует градиентный фон на всей карте, кроме территории Таджикистана.
class _OutsideBackgroundPainter extends CustomPainter {
  _OutsideBackgroundPainter(this.camera, this.outline, this.dark);

  final MapCamera camera;
  final List<List<double>> outline;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final taj = Path();
    for (var i = 0; i < outline.length; i++) {
      final o = camera.latLngToScreenOffset(LatLng(outline[i][1], outline[i][0]));
      if (i == 0) {
        taj.moveTo(o.dx, o.dy);
      } else {
        taj.lineTo(o.dx, o.dy);
      }
    }
    taj.close();
    final full = Path()..addRect(Offset.zero & size);
    final outside = Path.combine(PathOperation.difference, full, taj);
    final colors = dark
        ? const [Color(0xFF16302A), Color(0xFF0A1412)]
        : const [Color(0xFFF7FAF9), Color(0xFFD4E6DF)];
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Offset.zero & size);
    canvas.drawPath(outside, paint);
  }

  @override
  bool shouldRepaint(covariant _OutsideBackgroundPainter old) =>
      old.camera != camera || old.dark != dark;
}
