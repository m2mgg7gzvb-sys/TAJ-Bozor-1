import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Кнопка «Подписаться» на продавца: подписчик получает уведомления о его новых объявлениях.
class FollowButton extends StatefulWidget {
  const FollowButton({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool? _following;
  bool _busy = false;

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = _me;
    if (me == null) return;
    try {
      final row = await Supabase.instance.client
          .from('seller_follows')
          .select('seller_id')
          .eq('follower_id', me)
          .eq('seller_id', widget.sellerId)
          .maybeSingle();
      if (mounted) setState(() => _following = row != null);
    } catch (_) {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _toggle() async {
    final me = _me;
    if (me == null || _following == null || _busy) return;
    setState(() => _busy = true);
    try {
      final db = Supabase.instance.client;
      if (_following!) {
        await db.from('seller_follows').delete().eq('follower_id', me).eq('seller_id', widget.sellerId);
      } else {
        await db.from('seller_follows').insert({'follower_id': me, 'seller_id': widget.sellerId});
      }
      if (mounted) setState(() => _following = !_following!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось изменить подписку')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_me == null || _following == null) return const SizedBox.shrink();
    return _following!
        ? OutlinedButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Вы подписаны'),
          )
        : FilledButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: const Icon(Icons.notifications_none_rounded),
            label: const Text('Подписаться на продавца'),
          );
  }
}
