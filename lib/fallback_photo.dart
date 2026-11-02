import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// Картинка для объявления без фото: рисунок по категории, цвет — по номеру объявления.
class FallbackPhoto extends StatelessWidget {
  const FallbackPhoto({super.key, required this.item});

  final Map<String, dynamic> item;

  static const _known = {'auto', 'real-estate', 'electronics', 'home', 'services', 'jobs'};

  // bg1, bg2, light accent, dark accent
  static const _palettes = [
    ['#E6F4EC', '#CFE6DA', '#13A07A', '#0B6B50'],
    ['#FFF3D6', '#F8E2A8', '#F5B301', '#C98600'],
    ['#E3EEFF', '#C9DCFA', '#4C8DF0', '#2B5FB8'],
    ['#FDE8EE', '#F8CFDA', '#E24B6B', '#B02848'],
    ['#EEE8FF', '#DAD0FA', '#7B5FE0', '#5238B0'],
    ['#E2F5F4', '#C4E6E4', '#18A5A0', '#0F6F6B'],
  ];

  static final Map<String, Future<String>> _cache = {};

  static String _slug(Map<String, dynamic> item) {
    final c = item['categories'];
    String? slug;
    if (c is Map) {
      slug = c['slug'] as String?;
    } else if (c is List && c.isNotEmpty && c.first is Map) {
      slug = (c.first as Map)['slug'] as String?;
    }
    return slug != null && _known.contains(slug) ? slug : 'other';
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slug(item);
    var h = 0;
    for (final u in '${item['id']}'.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    final p = _palettes[h % _palettes.length];
    final future = _cache.putIfAbsent(
      slug,
      () => rootBundle.loadString('assets/photos/$slug.svg'),
    );
    return FutureBuilder<String>(
      future: future,
      builder: (context, snap) {
        final raw = snap.data;
        if (raw == null) {
          return ColoredBox(color: Color(int.parse('FF${p[0].substring(1)}', radix: 16)));
        }
        final svg = raw
            .replaceAll('{{bg1}}', p[0])
            .replaceAll('{{bg2}}', p[1])
            .replaceAll('{{a}}', p[2])
            .replaceAll('{{b}}', p[3]);
        return SvgPicture.string(
          svg,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  }
}
