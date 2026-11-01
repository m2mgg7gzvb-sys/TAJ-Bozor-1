import 'package:flutter/material.dart';

import 'account_tab.dart';
import 'favorites_screen.dart';
import 'favorites_store.dart';
import 'home_tab.dart';
import 'my_listings_tab.dart';
import 'theme.dart';

/// Основа приложения: нижнее меню из 5 вкладок, как в макете.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    FavoritesStore.load();
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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Поиск'),
          NavigationDestination(icon: Icon(Icons.favorite_border_rounded), label: 'Избранное'),
          NavigationDestination(icon: Icon(Icons.post_add_rounded), label: 'Объявления'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Сообщения'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Войти'),
        ],
      ),
    );
  }
}

/// Сообщения пока не реализованы.
class _MessagesTab extends StatelessWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщения')),
      body: const Center(
        child: Text('Переписка с продавцами появится в следующей версии',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      ),
    );
  }
}
