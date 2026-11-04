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
import 'theme.dart';

/// Основа приложения: нижнее меню из 5 вкладок.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = tabIndex.value;
    tabIndex.addListener(_onTabChanged);
    FavoritesStore.load();
  }

  @override
  void dispose() {
    tabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() => _index = tabIndex.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeTab(),
          FavoritesScreen(),
          MyListingsTab(),
          const _MessagesTab(),
          AccountTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), label: tr('Войти', 'Ворид')),
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
