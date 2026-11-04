import 'package:flutter/material.dart';

import 'favorites_store.dart';
import 'login_sheet.dart';
import 'theme.dart';

/// Сердечко «в избранное»: пружинит на 40 % за 0,28 с, снизу появляется
/// короткое подтверждение. Гостю показывает шторку входа.
class FavoriteHeart extends StatefulWidget {
  const FavoriteHeart({super.key, required this.listingId, this.size = 24});

  final String listingId;
  final double size;

  @override
  State<FavoriteHeart> createState() => _FavoriteHeartState();
}

class _FavoriteHeartState extends State<FavoriteHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.4, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    final ok = await requireLogin(context);
    if (!ok || !mounted) return;
    final wasFav = FavoritesStore.ids.value.contains(widget.listingId);
    if (!wasFav && !MediaQuery.of(context).disableAnimations) _c.forward(from: 0);
    final error = await FavoritesStore.toggle(widget.listingId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? (wasFav ? 'Убрано из избранного' : 'Добавлено в избранное')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesStore.ids,
      builder: (context, ids, _) {
        final fav = ids.contains(widget.listingId);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ScaleTransition(
              scale: _scale,
              child: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                size: widget.size,
                color: fav ? AppColors.ruby : AppColors.ink,
              ),
            ),
          ),
        );
      },
    );
  }
}
