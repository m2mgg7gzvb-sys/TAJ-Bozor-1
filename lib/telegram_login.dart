import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_intent.dart';

const _pendingKey = 'tg_login_pending';
const _pendingTtl = Duration(minutes: 10);
var _polling = false;

/// Запоминаем запрос входа, чтобы продолжить ожидание, если страница перезагрузится.
Future<void> _savePending(String nonce) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      '$nonce|${DateTime.now().millisecondsSinceEpoch}',
    );
  } catch (_) {}
}

Future<void> _clearPending() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  } catch (_) {}
}

Future<(String, DateTime)?> _loadPending() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final ms = int.tryParse(parts[1]);
    if (ms == null) return null;
    return (parts[0], DateTime.fromMillisecondsSinceEpoch(ms));
  } catch (_) {
    return null;
  }
}

/// Ждёт подтверждения в боте и входит. Возвращает текст ошибки или null при успехе.
/// Возвращает 'cancelled' при отмене из диалога.
Future<String?> _waitForLogin(String nonce, DateTime started, bool Function() cancelled) async {
  final client = Supabase.instance.client;
  final deadline = started.add(_pendingTtl);
  while (!cancelled() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (cancelled()) return 'cancelled';
    try {
      final res = await client.functions.invoke(
        'telegram-login',
        body: {'action': 'check', 'nonce': nonce},
      );
      final tokenHash = (res.data as Map<String, dynamic>?)?['token_hash'] as String?;
      if (tokenHash != null) {
        await client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
        return null;
      }
    } on FunctionException catch (e) {
      if (e.status == 404 || e.status == 410) return 'expired';
    } catch (_) {
      // Временная ошибка сети: продолжаем ждать
    }
  }
  return DateTime.now().isBefore(deadline) ? 'cancelled' : 'expired';
}

/// Продолжает ожидание входа после перезагрузки страницы (если запрос ещё действует).
Future<void> resumeTelegramLogin(BuildContext context) async {
  if (_polling) return;
  final pending = await _loadPending();
  if (pending == null) return;
  final (nonce, started) = pending;
  if (DateTime.now().difference(started) > _pendingTtl) {
    await _clearPending();
    return;
  }
  if (Supabase.instance.client.auth.currentSession != null) {
    await _clearPending();
    return;
  }
  _polling = true;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final error = await _waitForLogin(nonce, started, () => false);
  _polling = false;
  await _clearPending();
  if (error != null && error != 'cancelled') {
    messenger?.showSnackBar(const SnackBar(
      content: Text('Ссылка устарела. Начните вход заново'),
    ));
  }
}

/// Вход и регистрация через бота: открываем бота в Telegram, человек вводит код,
/// а сайт ждёт подтверждения и входит сам.
Future<void> startTelegramLogin(BuildContext context, {required bool register}) async {
  await rememberAuthIntent(register: register);
  final client = Supabase.instance.client;
  final messenger = ScaffoldMessenger.of(context);

  String nonce;
  String code;
  String bot;
  try {
    final res = await client.functions.invoke('telegram-login', body: {'action': 'start'});
    final data = res.data as Map<String, dynamic>;
    nonce = data['nonce'] as String;
    code = data['code'] as String;
    bot = data['bot'] as String;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Не удалось начать вход')));
    return;
  }

  final started = DateTime.now();
  await _savePending(nonce);

  await launchUrl(
    Uri.parse('https://t.me/$bot?start=login_$nonce'),
    mode: LaunchMode.externalApplication,
  );
  if (!context.mounted) return;

  var dialogOpen = true;
  var cancelled = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Подтвердите в Telegram'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Откройте бота и отправьте ему этот код. Потом вернитесь сюда: вход выполнится автоматически.',
          ),
          const SizedBox(height: 16),
          Center(
            child: SelectableText(
              code,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse('https://t.me/$bot?start=login_$nonce'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Открыть бота'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            Navigator.of(ctx).pop();
          },
          child: const Text('Отмена'),
        ),
      ],
    ),
  ).then((_) => dialogOpen = false);

  final error = await _waitForLogin(nonce, started, () => cancelled);
  await _clearPending();

  if (dialogOpen && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  if (error == null || error == 'cancelled') return;
  messenger.showSnackBar(SnackBar(
    content: Text(error == 'expired'
        ? 'Ссылка устарела. Начните вход заново'
        : 'Вход не подтверждён'),
  ));
}
