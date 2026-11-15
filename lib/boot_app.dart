import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import 'auth_intent.dart';
import 'call_widgets.dart';
import 'config.dart';
import 'connection_screens.dart';
import 'lang_store.dart';
import 'notify_store.dart';
import 'splash_screen.dart';
import 'theme.dart';
import 'viewed_store.dart';

/// Подключение к серверу и настройки приложения. Бросает ошибку, если не получилось.
Future<void> bootstrap() async {
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
}

/// Похоже ли, что ошибка из-за сети (нет интернета или сервер не ответил).
bool _looksOffline(Object e) {
  final msg = e.toString();
  return !web.window.navigator.onLine ||
      msg.contains('Failed to fetch') ||
      msg.contains('ClientException') ||
      msg.contains('SocketException') ||
      msg.contains('XMLHttpRequest');
}

enum _BootState { loading, offline, error, ready }

/// Первый экран: пока приложение подключается, показывает загрузку, а при проблеме —
/// экран без интернета или экран ошибки с кнопкой «Повторить».
class BootApp extends StatefulWidget {
  const BootApp({super.key});

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  _BootState _state = _BootState.loading;
  bool _starting = false;
  late final JSFunction _onlineListener = _onOnlineEvent.toJS;

  @override
  void initState() {
    super.initState();
    // Как только интернет вернулся, пробуем подключиться сами.
    web.window.addEventListener('online', _onlineListener);
    _start();
  }

  @override
  void dispose() {
    web.window.removeEventListener('online', _onlineListener);
    super.dispose();
  }

  void _onOnlineEvent(web.Event _) {
    if (_state == _BootState.offline) _start();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    if (mounted && _state != _BootState.loading) setState(() => _state = _BootState.loading);
    if (!web.window.navigator.onLine) {
      _starting = false;
      if (mounted) setState(() => _state = _BootState.offline);
      return;
    }
    try {
      await bootstrap();
      if (mounted) setState(() => _state = _BootState.ready);
    } catch (e) {
      if (mounted) {
        setState(() => _state = _looksOffline(e) ? _BootState.offline : _BootState.error);
      }
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _BootState.ready) return const TajBozorApp();
    final Widget home = switch (_state) {
      _BootState.offline => ConnectionScreen(problem: ConnectionProblem.offline, onRetry: _start),
      _BootState.error => ConnectionScreen(problem: ConnectionProblem.error, onRetry: _start),
      _ => const _LoadingScreen(),
    };
    return MaterialApp(
      title: 'TAJ Bozor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: home,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: CallBackground(
        child: Center(child: CircularProgressIndicator(color: kCallGold)),
      ),
    );
  }
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
