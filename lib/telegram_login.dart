import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_intent.dart';
import 'account_choice.dart';
import 'frosted_glass.dart';
import 'theme.dart';

const _pendingTtl = Duration(minutes: 10);
var _polling = false;

/// Два способа входа через мессенджеры: функция и ключ сохранённого запроса.
const _tgFn = 'telegram-login';
const _tgKey = 'tg_login_pending';
const _tgLinkKey = 'tg_link_pending';
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
  bool Function() cancelled, {
  bool link = false,
}) async {
  final client = Supabase.instance.client;
  final deadline = started.add(_pendingTtl);
  while (!cancelled() && DateTime.now().isBefore(deadline)) {
    final fast = DateTime.now().difference(started) < const Duration(seconds: 30);
    await Future<void>.delayed(Duration(milliseconds: fast ? 1000 : 2000));
    if (cancelled()) return 'cancelled';
    try {
      final res = await client.functions.invoke(fn, body: {'action': 'check', 'nonce': nonce});
      final data = res.data as Map<String, dynamic>?;
      if (link && data?['linked'] == true) return null;
      final tokenHash = data?['token_hash'] as String?;
      if (tokenHash != null) {
        // Окно выбора аккаунта при входе показываем только для входа через Telegram
        loginViaTelegram = true;
        await client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
        return null;
      }
    } on FunctionException catch (e) {
      if (e.status == 410) return 'expired';
      if (e.status == 409 && link) return 'taken';
      final tooLong = DateTime.now().difference(started) > const Duration(minutes: 1);
      if (e.status == 404 && tooLong) return 'expired';
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
    var cancelled = false;
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => _waitingDialog(
        icon: fn == _tgFn ? Icons.send_rounded : Icons.chat_rounded,
        onCancel: () {
          cancelled = true;
          Navigator.of(ctx).pop();
        },
      ),
    ).then((_) => dialogOpen = false);
    final error = await _waitForLogin(fn, nonce, started, () => cancelled);
    if (dialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
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

/// Окно «Ожидаем» с анимацией и отсчётом. Закрывается только кнопкой «Отмена» или по результату.
Dialog _waitingDialog({required IconData icon, required VoidCallback onCancel}) {
  return Dialog(
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
            'Ожидаем',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
          ),
          const SizedBox(height: 10),
          const _WaitingIndicator(),
          const SizedBox(height: 4),
          TextButton(onPressed: onCancel, child: const Text('Отмена')),
        ],
      ),
    ),
  );
}

/// Анимация «• • •» и обратный отсчёт 15 → 0 в окне ожидания.
class _WaitingIndicator extends StatefulWidget {
  const _WaitingIndicator();

  @override
  State<_WaitingIndicator> createState() => _WaitingIndicatorState();
}

class _WaitingIndicatorState extends State<_WaitingIndicator> {
  static const _seconds = 15;
  Timer? _dots;
  Timer? _tick;
  int _step = 0;
  int _left = _seconds;

  @override
  void initState() {
    super.initState();
    _dots = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _step = (_step + 1) % 4);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _dots?.cancel();
    _tick?.cancel();
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
        const SizedBox(height: 14),
        if (_left > 0)
          Text(
            '$_left',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
          )
        else
          Text(
            'Ссылка могла не открыться. Нажмите «Отмена» и начните вход заново',
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
  bool linkMode = false,
}) async {
  if (!linkMode) await rememberAuthIntent(register: register);
  final client = Supabase.instance.client;
  final messenger = ScaffoldMessenger.of(context);

  String nonce;
  Map<String, dynamic> data;
  try {
    final res = await client.functions.invoke(
      fn,
      body: linkMode ? {'action': 'start', 'link': true} : {'action': 'start'},
    );
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
  if (!context.mounted) return;

  // Окно сначала показывает кнопку. После открытия мессенджера оно становится «Ожидаем».
  final launched = ValueNotifier<bool>(false);
  var tapped = false;
  // Окно меняется на «Ожидаем» только после возврата на сайт, а не сразу по нажатию.
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (tapped) launched.value = true;
    },
  );
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
        child: ValueListenableBuilder<bool>(
          valueListenable: launched,
          builder: (_, isLaunched, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                isLaunched ? 'Ожидаем' : dialogTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
              ),
              const SizedBox(height: 10),
              if (isLaunched)
                const _WaitingIndicator()
              else ...[
                Text(
                  dialogText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      tapped = true;
                      _openMessenger(link, fallback);
                    },
                    child: Text(buttonLabel),
                  ),
                ),
              ],
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
    ),
  ).then((_) => dialogOpen = false);

  final error = await _waitForLogin(fn, nonce, started, () => cancelled, link: linkMode);
  await _clearPending(key);

  if (dialogOpen && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  lifecycle.dispose();
  launched.dispose();
  if (error == 'cancelled') return;
  if (error == null) {
    if (linkMode) messenger.showSnackBar(const SnackBar(content: Text('Telegram привязан')));
    return;
  }
  messenger.showSnackBar(SnackBar(
    content: Text(switch (error) {
      'expired' => 'Ссылка устарела. Начните заново',
      'taken' => 'Этот Telegram уже привязан к другому аккаунту',
      _ => 'Вход не подтверждён',
    }),
  ));
}

/// Привязка Telegram к уже вошедшему аккаунту (вход не создаётся).
Future<void> startTelegramLink(BuildContext context) {
  return _startMessengerLogin(
    context,
    register: false,
    fn: _tgFn,
    key: _tgLinkKey,
    dialogTitle: 'Подтвердите в Telegram',
    dialogText: 'Откройте бота и нажмите Start. Telegram привяжется к вашему аккаунту.',
    buttonLabel: 'Открыть бота',
    icon: Icons.send_rounded,
    linkFor: (data, nonce) =>
        Uri.parse('tg://resolve?domain=${data['bot']}&start=login_$nonce'),
    fallbackFor: (data, nonce) =>
        Uri.parse('https://t.me/${data['bot']}?start=login_$nonce'),
    linkMode: true,
  );
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
