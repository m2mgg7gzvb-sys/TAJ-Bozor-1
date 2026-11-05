import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'confirm_delete.dart';
import 'theme.dart';

/// Проверка объявлений для админов: новые и изменённые объявления ждут решения.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _db
        .from('listings')
        .select('$listingSelect, status')
        .eq('status', 'moderation')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  void _reload() => setState(() => _future = _load());

  /// Меняет статус объявления: active — разрешить, blocked — заблокировать, hidden — удалить.
  Future<void> _set(String id, String status, String message) async {
    try {
      await _db.from('listings').update({'status': status}).eq('id', id);
      _reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить решение')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка объявлений')),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Не удалось загрузить объявления',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              );
            }
            final items = snap.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Объявлений на проверке нет',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items) ...[
                  _ModerationTile(
                    item: item,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ListingDetailScreen(item: item)),
                    ),
                    onApprove: () => _set(item['id'] as String, 'active', 'Объявление опубликовано'),
                    onBlock: () => _set(item['id'] as String, 'blocked', 'Объявление заблокировано'),
                    onDelete: () async {
                      if (await confirmDeleteByTyping(context)) {
                        _set(item['id'] as String, 'hidden', 'Объявление удалено');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModerationTile extends StatelessWidget {
  const _ModerationTile({
    required this.item,
    required this.onOpen,
    required this.onApprove,
    required this.onBlock,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onBlock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final photo = photoUrl(item);
    final city = (item['city'] as String?) ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: photo == null
                        ? Container(color: AppColors.mint)
                        : Image.network(photo, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['title'] as String?) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(priceText(item), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                      if (city.isNotEmpty)
                        Text(city, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onApprove, child: const Text('Разрешить')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: onBlock, child: const Text('Блокировать')),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDelete,
                child: Text('Удалить', style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
