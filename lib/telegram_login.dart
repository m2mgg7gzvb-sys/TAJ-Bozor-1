import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import 'auth_intent.dart';
import 'config.dart';

/// ID бота @tajbozor_tg_bot (число до двоеточия в токене). Не секретный.
const _botId = '9261235321';
const _siteUrl = 'https://app.tajbozor.pro';

/// Открывает страницу Telegram для входа. После подтверждения Telegram вернёт нас на сайт.
Future<void> startTelegramLogin(BuildContext context, {required bool register}) async {
  await rememberAuthIntent(register: register);
  final uri = Uri.parse(
    'https://oauth.telegram.org/auth?bot_id=$_botId&origin=$_siteUrl&request_access=write&return_to=$_siteUrl/',
  );
  final ok = await launchUrl(uri, webOnlyWindowName: '_self');
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть Telegram')),
    );
  }
}

/// Если Telegram вернул пользователя с данными входа (в адресе после #tgAuthResult=),
/// проверяем их на сервере и завершаем вход.
Future<void> finishTelegramLoginIfReturned() async {
  final frag = Uri.base.fragment;
  const prefix = 'tgAuthResult=';
  if (!frag.startsWith(prefix)) return;
  try {
    var encoded = frag.substring(prefix.length);
    while (encoded.length % 4 != 0) {
      encoded += '=';
    }
    final data = jsonDecode(utf8.decode(base64Url.decode(encoded))) as Map<String, dynamic>;

    // Убираем данные входа из адреса, чтобы не обрабатывать их повторно
    web.window.history.replaceState(null, '', Uri.base.path);

    final res = await Supabase.instance.client.functions.invoke(
      'telegram-login',
      body: data.map((k, v) => MapEntry(k, v?.toString())),
    );
    final body = res.data as Map<String, dynamic>?;
    final tokenHash = body?['token_hash'] as String?;
    if (tokenHash == null) return;
    await Supabase.instance.client.auth.verifyOTP(
      type: OtpType.magiclink,
      tokenHash: tokenHash,
    );
  } catch (_) {
    // Если что-то пошло не так, человек просто остаётся на экране входа
  }
}
