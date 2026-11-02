import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'welcome_screen.dart';
import 'my_listings_tab.dart';
import 'nav_state.dart';
import 'theme.dart';

/// Вкладка «Войти»: форма входа, если никто не вошёл, иначе профиль.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const WelcomeScreen();
    return _ProfilePage(user: user);
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final isGuest = user.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('profiles')
            .select('name, city')
            .eq('id', user.id)
            .maybeSingle(),
        builder: (context, snapshot) {
          final name = isGuest ? 'Гость' : (snapshot.data?['name'] as String? ?? 'Пользователь');
          final city = snapshot.data?['city'] as String?;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(name: name, city: city, email: user.email),
              const SizedBox(height: 16),
              if (isGuest) ...[
                const _GuestBanner(),
                const SizedBox(height: 16),
              ],
              _MenuCard(
                children: [
                  _MenuTile(
                    icon: Icons.list_alt_rounded,
                    title: 'Мои объявления',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyListingsTab()),
                    ),
                  ),
                  _MenuTile(
                    icon: Icons.favorite_border_rounded,
                    title: 'Избранное',
                    onTap: () => tabIndex.value = 1,
                  ),
                  _MenuTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Сообщения',
                    onTap: () => tabIndex.value = 3,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Выйти'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.city, required this.email});

  final String name;
  final String? city;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primary,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (city != null && city!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(city!, style: const TextStyle(color: AppColors.muted)),
                ],
                const SizedBox(height: 4),
                Text(
                  email ?? 'Вход без почты',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Вы вошли как гость',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Зарегистрируйтесь по почте, чтобы не потерять объявления и избранное.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _RegisterPage()),
            ),
            child: const Text('Зарегистрироваться'),
          ),
        ],
      ),
    );
  }
}

/// Экран регистрации поверх гостевого входа. Закрывается сам, когда пользователь подтвердил почту.
class _RegisterPage extends StatefulWidget {
  const _RegisterPage();

  @override
  State<_RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<_RegisterPage> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final user = state.session?.user;
      if (user != null && !user.isAnonymous && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AuthScreen();
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(radius: 18),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
