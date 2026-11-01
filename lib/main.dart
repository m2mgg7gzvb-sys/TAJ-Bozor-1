import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'categories_screen.dart';
import 'config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseKey,
  );
  runApp(const TajBozorApp());
}

class TajBozorApp extends StatelessWidget {
  const TajBozorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAJBozor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootGate(),
    );
  }
}

/// Показывает вход, если пользователь не авторизован, иначе — главный экран.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const AuthScreen();
        return const CategoriesScreen();
      },
    );
  }
}
