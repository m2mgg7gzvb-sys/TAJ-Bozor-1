import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'listing_detail_screen.dart';
import 'listing_utils.dart';

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
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tajbozor.app',
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
