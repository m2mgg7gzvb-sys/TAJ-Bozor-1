import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';

/// Пока идёт привязка или переключение аккаунта, окно выбора при входе не показываем.
bool accountLinkingBusy = false;

var _choiceShown = false;

/// Окно выбора при входе: если у вошедшего аккаунта есть связанные (привязка или Telegram),
/// спрашиваем, в какой войти. Показываем один раз за запуск приложения.
Future<void> maybeShowAccountChoice(BuildContext context) async {
  if (_choiceShown || accountLinkingBusy) return;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return;
  try {
    final res = await client.functions.invoke('account-link', body: {'action': 'links'});
    final list = (res.data as Map<String, dynamic>?)?['alternatives'] as List? ?? const [];
    if (list.isEmpty || !context.mounted) return;
    _choiceShown = true;
    final alternatives = list.cast<Map<String, dynamic>>();
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr('В какой аккаунт войти?', 'Ба кадом ҳисоб ворид шавем?')),
        content: Text(tr(
          'Этот способ входа связан с другим аккаунтом. Можно войти в него или остаться здесь.',
          'Ин роҳи воридшавӣ бо ҳисоби дигар пайваст аст. Ба он ворид шуда метавонед ё дар ин ҷо монед.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Остаться здесь', 'Инҷо мондан')),
          ),
          for (final a in alternatives)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(a),
              child: Text(_label(a)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    accountLinkingBusy = true;
    try {
      final sw = await client.functions.invoke(
        'account-link',
        body: {'action': 'switch', 'target_user_id': picked['id']},
      );
      final tokenHash = (sw.data as Map<String, dynamic>?)?['token_hash'] as String?;
      if (tokenHash == null) return;
      await client.auth.verifyOTP(type: OtpType.magiclink, tokenHash: tokenHash);
    } finally {
      accountLinkingBusy = false;
    }
  } catch (_) {
    // Если проверка не прошла, просто входим в текущий аккаунт
  }
}

String _label(Map<String, dynamic> a) {
  final name = (a['name'] as String?)?.trim() ?? '';
  final email = (a['email'] as String?) ?? '';
  final shown = name.isNotEmpty ? name : email;
  return tr('Войти в «$shown»', 'Ба «$shown» ворид шудан');
}
