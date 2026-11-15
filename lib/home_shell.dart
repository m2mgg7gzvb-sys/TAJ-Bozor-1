import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_tab.dart';
import 'favorites_screen.dart';
import 'favorites_store.dart';
import 'guest_prompt.dart';
import 'home_tab.dart';
import 'lang_store.dart';
import 'messages_tab.dart';
import 'my_listings_tab.dart';
import 'nav_state.dart';
import 'notify_store.dart';
import 'push.dart';
import 'frosted_glass.dart';
import 'theme.dart';
import 'wave_background.dart';
import 'green_button.dart';

/// Основа приложения: нижнее меню из 5 вкладок.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;
  late final StreamSubscription<AuthState> _authSub;
  bool _pushAsked = false;

  @override
  void initState() {
    super.initState();
    _index = tabIndex.value;
    tabIndex.addListener(_onTabChanged);
    FavoritesStore.load();
    // Подпись последней вкладки меняется после входа и выхода: «Войти» → «Профиль».
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (mounted) setState(() {});
      if (state.event == AuthChangeEvent.signedIn) _askPush();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPush());
  }

  /// Спрашивает про уведомления, если разрешение ещё не выбрано. За один запуск — один раз.
  Future<void> _askPush() async {
    if (_pushAsked || !mounted) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    _pushAsked = true;
    if (pushPermission() != 'default') return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Уведомления'),
        content: const Text(
          'Присылать уведомления о новых сообщениях и ответах на ваши объявления на телефон?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Не сейчас'),
          ),
          GreenButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Включить'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final err = await enablePush();
    messenger.showSnackBar(SnackBar(
      content: Text(err ?? 'Уведомления включены'),
    ));
  }

  @override
  void dispose() {
    tabIndex.removeListener(_onTabChanged);
    _authSub.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() => _index = tabIndex.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: WaveBackground(
        child: IndexedStack(
          index: _index,
          children: [
            HomeTab(),
            FavoritesScreen(),
            MyListingsTab(),
            const _MessagesTab(),
            AccountTab(),
          ],
        ),
      ),
      bottomNavigationBar: _GlassTabBar(
        index: _index,
        onChanged: (i) => tabIndex.value = i,
        items: [
          _NavItem(icon: const Icon(Icons.search_rounded), label: tr('Поиск', 'Ҷустуҷӯ')),
          _NavItem(icon: const Icon(Icons.favorite_border_rounded), label: tr('Избранное', 'Интихобшуда')),
          _NavItem(icon: const Icon(Icons.post_add_rounded), label: tr('Объявления', 'Эълонҳо')),
          _NavItem(
            icon: ValueListenableBuilder<bool>(
              valueListenable: hasUnread,
              builder: (_, has, __) => Badge(
                isLabelVisible: has,
                smallSize: 9,
                backgroundColor: Colors.red,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
            label: tr('Сообщения', 'Паёмҳо'),
          ),
          _NavItem(
            icon: const Icon(Icons.person_outline_rounded),
            label: Supabase.instance.client.auth.currentSession != null
                ? tr('Профиль', 'Профил')
                : tr('Войти', 'Ворид'),
          ),
        ],
      ),
    );
  }
}

/// Сообщения: гостю — экран входа, вошедшему — заглушка до появления переписки.
class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    if (loggedIn) return const MessagesTab();
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: const GuestPrompt(
              icon: Icons.chat_bubble_rounded,
              title: 'Войдите, чтобы писать продавцам',
              text: 'Переписка в приложении удобна и безопасна: все детали по объявлению в одном месте.',
            ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final Widget icon;
  final String label;
}

/// Нижняя панель в стиле iOS: стеклянная капсула, по которой плавно скользит подсветка
/// к выбранной вкладке. Можно нажать или провести пальцем по панели.
class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.items, required this.index, required this.onChanged});

  final List<_NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: FrostedGlass(
        height: 68,
        radius: 34,
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) {
                final i = (d.localPosition.dx / constraints.maxWidth * n).floor().clamp(0, n - 1);
                if (i != index) onChanged(i);
              },
              child: Stack(
                children: [
                  // Подсветка-капля: плавно переезжает к выбранной вкладке.
                  AnimatedAlign(
                    duration: Duration.zero,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(n <= 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.24),
                              AppColors.primary.withValues(alpha: 0.08),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 14,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onChanged(i),
                            child: _TabCell(item: items[i], selected: i == index),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({required this.item, required this.selected});

  final _NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1.0,
            duration: Duration.zero,
            curve: Curves.easeOutBack,
            child: IconTheme(data: IconThemeData(color: color, size: 24), child: item.icon),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: Duration.zero,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
            child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
