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
import 'theme.dart';
import 'wave_background.dart';

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
          FilledButton(
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: AppColors.deep.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.94),
              child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: _index,
        onDestinationSelected: (i) => tabIndex.value = i,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: tr('Поиск', 'Ҷустуҷӯ')),
          NavigationDestination(icon: const Icon(Icons.favorite_border_rounded), label: tr('Избранное', 'Интихобшуда')),
          NavigationDestination(icon: const Icon(Icons.post_add_rounded), label: tr('Объявления', 'Эълонҳо')),
          NavigationDestination(
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
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            label: Supabase.instance.client.auth.currentSession != null
                ? tr('Профиль', 'Профил')
                : tr('Войти', 'Ворид'),
          ),
        ],
              ),
            ),
          ),
        ),
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
