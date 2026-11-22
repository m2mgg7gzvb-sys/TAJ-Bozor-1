import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';

/// Пока идёт привязка или переключение аккаунта, окно выбора при входе не показываем.
bool accountLinkingBusy = false;

var _choiceShown = false;

/// Окно выбора при входе: если вошли в привязанный аккаунт, спрашиваем, в какой войти.
/// Показываем один раз за запуск приложения.
Future<void> maybeShowAccountChoice(BuildContext context) async {
  if (_choiceShown || accountLinkingBusy) return;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return;
  try {
    final res = await client.functions.invoke('account-link', body: {'action': 'links'});
    final owner = (res.data as Map<String, dynamic>?)?['owner'] as Map<String, dynamic>?;
    if (owner == null || !context.mounted) return;
    _choiceShown = true;
    final ownerId = owner['id'] as String;
    final ownerLabel = (owner['name'] as String?)?.trim().isNotEmpty == true
        ? owner['name'] as String
        : (owner['email'] as String? ?? '');
    final choose = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr('В какой аккаунт войти?', 'Ба кадом ҳисоб ворид шавем?')),
        content: Text(tr(
          'Этот способ входа связан с аккаунтом «$ownerLabel». Можно войти в него или остаться здесь.',
          'Ин роҳи воридшавӣ ба ҳисоби «$ownerLabel» пайваст аст. Ба он ворид шуда метавонед ё дар ин ҷо монед.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Остаться здесь', 'Инҷо мондан')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Войти в «$ownerLabel»', 'Ба «$ownerLabel» ворид шудан')),
          ),
        ],
      ),
    );
    if (choose != true) return;
    accountLinkingBusy = true;
    try {
      final sw = await client.functions.invoke(
        'account-link',
        body: {'action': 'switch', 'target_user_id': ownerId},
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
