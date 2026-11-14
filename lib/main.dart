import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_intent.dart';
import 'config.dart';
import 'lang_store.dart';
import 'notify_store.dart';
import 'splash_screen.dart';
import 'theme.dart';
import 'viewed_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseKey,
  );
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    final session = state.session;
    if (state.event == AuthChangeEvent.signedIn && session != null) {
      checkAuthIntent(session.user);
    }
  });
  await ViewedStore.load();
  await loadLang();
  startNotifications();
  runApp(const TajBozorApp());
}

class TajBozorApp extends StatelessWidget {
  const TajBozorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: tajikLang,
      builder: (_, __, ___) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'TAJ Bozor',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const SplashScreen(),
      ),
    );
  }
}
