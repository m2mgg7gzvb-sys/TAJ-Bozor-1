import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';
import 'welcome_screen.dart';

/// Перестраивает приложение при входе и выходе пользователя.
/// Ключ — id пользователя: при входе или выходе оболочка пересоздаётся, а при обновлении токена остаётся на месте.
/// Гостю при запуске сначала показываем окно «Войти» после логотипа; «Пропустить» открывает приложение.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  /// Окно при запуске показываем один раз за сессию приложения.
  static bool _launchWelcomeDone = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null && !_launchWelcomeDone) {
          return WelcomeScreen(
            onSkip: () => setState(() => _launchWelcomeDone = true),
          );
        }
        return HomeShell(key: ValueKey(user?.id));
      },
    );
  }
}
