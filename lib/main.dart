import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'categories_screen.dart';
import 'config.dart';

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
    const green = Color(0xFF0B7A5A);
    return MaterialApp(
      title: 'TAJBozor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
        useMaterial3: true,
        fontFamily: null,
      ),
      home: const RootGate(),
    );
  }
}

/// Показывает вход, если пользователь не авторизован, иначе — категории.
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
