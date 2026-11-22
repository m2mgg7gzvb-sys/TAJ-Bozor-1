import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';

/// Пока идёт привязка или переключение аккаунта, окно выбора при входе не показываем.
bool accountLinkingBusy = false;

var _choiceShown = false;

/// Отмечает, что выбор аккаунта уже сделан при входе (окно при входе повторно не показываем).
void markChoiceDone() => _choiceShown = true;

/// Окно выбора при входе для любого способа входа: если у аккаунта есть связанные,
/// показываем все аккаунты (аватар, имя, ID, «Основной» / «Привязка») и даём выбрать.
/// Показываем один раз за запуск приложения.
Future<void> maybeShowAccountChoice(BuildContext context) async {
  if (_choiceShown || accountLinkingBusy) return;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return;
  try {
    final res = await client.functions.invoke('account-link', body: {'action': 'links'});
    final data = res.data as Map<String, dynamic>?;
    final accounts = (data?['accounts'] as List? ?? const []).cast<Map<String, dynamic>>();
    final me = data?['me'] as String?;
    if (accounts.length < 2 || me == null || !context.mounted) return;
    _choiceShown = true;
    final picked = await showAccountPicker(context, accounts);
    if (picked == null || picked['id'] == me) return;
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

/// Выбор аккаунта: аватар, имя, ID аккаунта и метка «Основной» или «Привязка».
/// Возвращает выбранный аккаунт или null (отмена / остаться).
Future<Map<String, dynamic>?> showAccountPicker(
  BuildContext context,
  List<Map<String, dynamic>> candidates,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(tr('В какой аккаунт войти?', 'Ба кадом ҳисоб ворид шавем?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.of(ctx).pop(c),
              leading: _avatarFor(c),
              title: Text(
                (c['name'] as String?)?.trim().isNotEmpty == true
                    ? c['name'] as String
                    : tr('Пользователь', 'Корбар'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if ((c['public_id'] as String?)?.isNotEmpty == true)
                    'ID: ${c['public_id']}',
                  c['role'] == 'Основной'
                      ? tr('Основной', 'Асосӣ')
                      : tr('Привязка', 'Пайванд'),
                ].join('  ·  '),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('Отмена', 'Бекор')),
        ),
      ],
    ),
  );
}

Widget _avatarFor(Map<String, dynamic> c) {
  final url = c['avatar_url'] as String?;
  final name = (c['name'] as String?)?.trim() ?? '';
  final letter = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  if (url != null && url.isNotEmpty) {
    return CircleAvatar(radius: 22, backgroundImage: NetworkImage(url));
  }
  return CircleAvatar(radius: 22, child: Text(letter));
}
