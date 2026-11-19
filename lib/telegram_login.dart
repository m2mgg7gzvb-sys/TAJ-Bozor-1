import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_intent.dart';
import 'frosted_glass.dart';
import 'theme.dart';

const _pendingTtl = Duration(minutes: 10);
var _polling = false;

/// Два способа входа через мессенджеры: функция и ключ сохранённого запроса.
const _tgFn = 'telegram-login';
const _tgKey = 'tg_login_pending';
const _waFn = 'whatsapp-login';
const _waKey = 'wa_login_pending';

/// Запоминаем запрос входа, чтобы продолжить ожидание, если страница перезагрузится.
Future<void> _savePending(String key, String nonce) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, '$nonce|${DateTime.now().millisecondsSinceEpoch}');
  } catch (_) {}
}

Future<void> _clearPending(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  } catch (_) {}
}

Future<(String, DateTime)?> _loadPending(String key) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
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

/// Открывает мессенджер напрямую (без промежуточной веб-страницы, которая мигала белым экраном).
/// Если приложение не открылось, открывает запасную ссылку.
Future<void> _openMessenger(Uri primary, Uri? fallback) async {
  try {
    final ok = await launchUrl(primary, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {}
  if (fallback != null) {
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}

/// Ждёт подтверждения и входит. Возвращает null при успехе, 'cancelled', 'expired' или 'failed'.
Future<String?> _waitForLogin(
  String fn,
  String nonce,
  DateTime started,
  bool Function() cancelled,
) async {
  final client = Supabase.instance.client;
  final deadline = started.add(_pendingTtl);
  while (!cancelled() && DateTime.now().isBefore(deadline)) {
    final fast = DateTime.now().difference(started) < const Duration(seconds: 30);
    await Future<void>.delayed(Duration(milliseconds: fast ? 1000 : 2000));
    if (cancelled()) return 'cancelled';
    try {
      final res = await client.functions.invoke(fn, body: {'action': 'check', 'nonce': nonce});
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
  if (Supabase.instance.client.auth.currentSession != null) {
    await _clearPending(_tgKey);
    await _clearPending(_waKey);
    return;
  }
  for (final (fn, key) in [(_tgFn, _tgKey), (_waFn, _waKey)]) {
    final pending = await _loadPending(key);
    if (pending == null) continue;
    final (nonce, started) = pending;
    if (DateTime.now().difference(started) > _pendingTtl) {
      await _clearPending(key);
      continue;
    }
    _polling = true;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final error = await _waitForLogin(fn, nonce, started, () => false);
    _polling = false;
    await _clearPending(key);
    if (error == 'expired') {
      messenger?.showSnackBar(const SnackBar(
        content: Text('Ссылка устарела. Начните вход заново'),
      ));
    }
    return;
  }
}

/// Анимация ожидания «• • •». Через 15 секунд показываем подсказку, если вход не прошёл.
class _WaitingIndicator extends StatefulWidget {
  const _WaitingIndicator();

  @override
  State<_WaitingIndicator> createState() => _WaitingIndicatorState();
}

class _WaitingIndicatorState extends State<_WaitingIndicator> {
  static const _hintAfter = Duration(seconds: 15);
  Timer? _dots;
  Timer? _hint;
  int _step = 0;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _dots = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
    });
    _hint = Timer(_hintAfter, () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _dots?.cancel();
    _hint?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: i < _step ? 1 : 0.2),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _showHint
              ? 'Вход занимает дольше обычного. Нажмите кнопку выше и попробуйте ещё раз'
              : 'Ждём подтверждения',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Общий сценарий входа через мессенджер: запрос, открытие чата, стеклянное окно ожидания.
Future<void> _startMessengerLogin(
  BuildContext context, {
  required bool register,
  required String fn,
  required String key,
  required String dialogTitle,
  required String dialogText,
  required String buttonLabel,
  required IconData icon,
  required Uri Function(Map<String, dynamic> data, String nonce) linkFor,
  Uri Function(Map<String, dynamic> data, String nonce)? fallbackFor,
}) async {
  await rememberAuthIntent(register: register);
  final client = Supabase.instance.client;
  final messenger = ScaffoldMessenger.of(context);

  String nonce;
  Map<String, dynamic> data;
  try {
    final res = await client.functions.invoke(fn, body: {'action': 'start'});
    data = res.data as Map<String, dynamic>;
    nonce = data['nonce'] as String;
  } on FunctionException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.status == 503
          ? 'Вход через WhatsApp скоро появится'
          : 'Не удалось начать вход'),
    ));
    return;
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Не удалось начать вход')));
    return;
  }

  final started = DateTime.now();
  await _savePending(key, nonce);

  final link = linkFor(data, nonce);
  final fallback = fallbackFor?.call(data, nonce);
  await _openMessenger(link, fallback);
  if (!context.mounted) return;

  var dialogOpen = true;
  var cancelled = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: FrostedGlass(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              dialogTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
            ),
            const SizedBox(height: 10),
            Text(
              dialogText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openMessenger(link, fallback),
                child: Text(buttonLabel),
              ),
            ),
            const SizedBox(height: 14),
            const _WaitingIndicator(),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                cancelled = true;
                Navigator.of(ctx).pop();
              },
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    ),
  ).then((_) => dialogOpen = false);

  final error = await _waitForLogin(fn, nonce, started, () => cancelled);
  await _clearPending(key);

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

/// Вход и регистрация через бота Telegram.
Future<void> startTelegramLogin(BuildContext context, {required bool register}) {
  return _startMessengerLogin(
    context,
    register: register,
    fn: _tgFn,
    key: _tgKey,
    dialogTitle: 'Подтвердите в Telegram',
    dialogText: 'Откройте бота и нажмите Start. Потом вернитесь сюда: вход выполнится автоматически.',
    buttonLabel: 'Открыть бота',
    icon: Icons.send_rounded,
    linkFor: (data, nonce) =>
        Uri.parse('tg://resolve?domain=${data['bot']}&start=login_$nonce'),
    fallbackFor: (data, nonce) =>
        Uri.parse('https://t.me/${data['bot']}?start=login_$nonce'),
  );
}

/// Вход и регистрация через WhatsApp: открываем чат с нашим номером с готовым текстом.
Future<void> startWhatsappLogin(BuildContext context, {required bool register}) {
  return _startMessengerLogin(
    context,
    register: register,
    fn: _waFn,
    key: _waKey,
    dialogTitle: 'Подтвердите в WhatsApp',
    dialogText:
        'Откройте чат и отправьте готовое сообщение. Потом вернитесь сюда: вход выполнится автоматически.',
    buttonLabel: 'Открыть WhatsApp',
    icon: Icons.chat_rounded,
    linkFor: (data, nonce) => Uri.parse(
        'whatsapp://send?phone=${data['number']}&text=login_$nonce'),
    fallbackFor: (data, nonce) => Uri.parse(
        'https://wa.me/${data['number']}?text=login_$nonce'),
  );
}
