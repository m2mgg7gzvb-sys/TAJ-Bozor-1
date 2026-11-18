import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_intent.dart';

/// Вход и регистрация через бота: открываем бота в Telegram, человек делится контактом,
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

  final deadline = DateTime.now().add(const Duration(minutes: 5));
  var expired = false;
  while (!cancelled && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (cancelled) break;
    try {
      final res = await client.functions.invoke(
        'telegram-login',
        body: {'action': 'check', 'nonce': nonce},
      );
      final tokenHash = (res.data as Map<String, dynamic>?)?['token_hash'] as String?;
      if (tokenHash != null) {
        if (dialogOpen && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        await client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
        return;
      }
    } on FunctionException catch (e) {
      if (e.status == 404 || e.status == 410) {
        expired = true;
        break;
      }
    } catch (_) {
      // Временная ошибка сети: продолжаем ждать
    }
  }

  if (dialogOpen && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  messenger.showSnackBar(SnackBar(
    content: Text(expired
        ? 'Ссылка устарела. Начните вход заново'
        : 'Вход не подтверждён'),
  ));
}
