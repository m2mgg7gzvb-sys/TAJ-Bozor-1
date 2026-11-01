import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'theme.dart';

/// Вкладка «Войти»: форма входа для гостя, профиль для вошедшего пользователя.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return const AuthScreen();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .maybeSingle(),
        builder: (context, snapshot) {
          final name = snapshot.data?['name'] as String? ?? 'Пользователь';
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.mint,
                  child: Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(user.email ?? '', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 32),
                OutlinedButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Выйти'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
