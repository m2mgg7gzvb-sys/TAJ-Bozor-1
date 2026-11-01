import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'favorites_screen.dart';
import 'favorites_store.dart';
import 'home_tab.dart';
import 'listings_screen.dart';
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
        children: const [
          HomeTab(),
          FavoritesScreen(),
          ListingsScreen(),
          _NeedLoginTab(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Сообщения',
            text: 'Вход нужен, чтобы писать продавцам',
          ),
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

/// Заглушка для вкладок, которым нужен вход.
class _NeedLoginTab extends StatelessWidget {
  const _NeedLoginTab({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                loggedIn ? title : 'Войдите в TAJ Bozor',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                loggedIn ? 'Пока здесь пусто' : text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Вкладка «Войти»: вход, если гость, и профиль с выходом, если вошли.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Гость';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.account_circle_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Supabase.instance.client.auth.signOut(),
              child: const Text('Выйти'),
            ),
          ],
        ),
      ),
    );
  }
}
