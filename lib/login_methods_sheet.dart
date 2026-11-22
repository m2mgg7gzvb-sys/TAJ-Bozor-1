import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';
import 'theme.dart';

const _linkRedirect = 'https://app.tajbozor.pro';

/// Шторка «Способы входа»: что привязано к аккаунту и что можно привязать ещё.
Future<void> showLoginMethodsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _LoginMethodsSheet(),
  );
}

class _LoginMethodsSheet extends StatefulWidget {
  const _LoginMethodsSheet();

  @override
  State<_LoginMethodsSheet> createState() => _LoginMethodsSheetState();
}

class _LoginMethodsSheetState extends State<_LoginMethodsSheet> {
  bool? _isPrimary;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _checkPrimary();
  }

  Future<void> _checkPrimary() async {
    try {
      final res = await Supabase.instance.client.rpc('is_primary_account');
      if (mounted) setState(() => _isPrimary = res == true);
    } catch (_) {
      if (mounted) setState(() => _isPrimary = false);
    }
  }

  static const _providers = <String, _ProviderInfo>{
    'google': _ProviderInfo('Google', OAuthProvider.google, enabled: true),
    // Вход через Apple ещё не настроен: кнопка видна, но не нажимается.
    'apple': _ProviderInfo('Apple', OAuthProvider.apple, enabled: false),
  };

  void _fail(String text) {
    if (!mounted) return;
    setState(() {
      _error = text;
      _info = null;
    });
  }

  void _ok(String text) {
    if (!mounted) return;
    setState(() {
      _info = text;
      _error = null;
    });
  }

  Future<void> _linkOAuth(OAuthProvider provider) async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.linkIdentity(provider, redirectTo: _linkRedirect);
    } catch (_) {
      _fail(tr(
        'Не удалось привязать. Возможно, этот способ уже привязан к другому аккаунту.',
        'Пайваст карда нашуд. Шояд ин роҳ ба ҳисоби дигар пайваст шуда бошад.',
      ));
    }
  }

  /// Привязка почты: Supabase шлёт письмо на новый адрес, после подтверждения почта добавляется к аккаунту.
  Future<void> _linkEmail() async {
    final email = await _askText(
      title: tr('Привязать почту', 'Пайваст кардани почта'),
      hint: 'name@example.com',
      keyboard: TextInputType.emailAddress,
    );
    if (email == null || email.isEmpty) return;
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(email: email));
      _ok(tr(
        'Письмо отправлено на $email. Откройте его и подтвердите.',
        'Мактуб ба $email фиристода шуд. Онро кушоед ва тасдиқ кунед.',
      ));
    } catch (_) {
      _fail(tr(
        'Не удалось отправить письмо. Возможно, эта почта уже занята.',
        'Мактуб фиристода нашуд. Шояд ин почта банд аст.',
      ));
    }
  }

  /// Привязка телефона: код приходит SMS, затем подтверждаем его.
  Future<void> _linkPhone() async {
    final phone = await _askText(
      title: tr('Привязать телефон', 'Пайваст кардани телефон'),
      hint: '+992...',
      keyboard: TextInputType.phone,
    );
    if (phone == null || phone.isEmpty) return;
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(phone: phone));
    } catch (_) {
      _fail(tr('Не удалось отправить код на телефон', 'Рамзро ба телефон фиристода нашуд'));
      return;
    }
    final code = await _askText(
      title: tr('Код из SMS', 'Рамз аз SMS'),
      hint: '123456',
      keyboard: TextInputType.number,
    );
    if (code == null || code.isEmpty) return;
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.phoneChange,
        phone: phone,
        token: code,
      );
      _ok(tr('Телефон привязан', 'Телефон пайваст шуд'));
    } catch (_) {
      _fail(tr('Неверный код', 'Рамз нодуруст аст'));
    }
  }

  Future<String?> _askText({
    required String title,
    required String hint,
    required TextInputType keyboard,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboard,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('Отмена', 'Бекор')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(tr('Далее', 'Идома')),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _unlink(UserIdentity identity) async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.unlinkIdentity(identity);
      if (mounted) setState(() {});
    } catch (_) {
      _fail(tr('Не удалось отвязать способ входа', 'Ҷудо кардани роҳ нашуд'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final identities = user?.identities ?? const <UserIdentity>[];
    final linked = identities.map((i) => i.provider).toSet();
    final canChange = _isPrimary == true;
    final unlinkedProviders = _providers.entries.where((e) => !linked.contains(e.key)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Способы входа', 'Роҳҳои воридшавӣ'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                tr(
                  'Все способы открывают один и тот же аккаунт.',
                  'Ҳамаи роҳҳо ба ҳамон як ҳисоб медароянд.',
                ),
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              if (_isPrimary == null)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else ...[
                for (final identity in identities)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                    title: Text(_providers[identity.provider]?.title ?? _labelFor(identity.provider),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(_subtitleFor(identity)),
                    trailing: canChange && identities.length > 1
                        ? TextButton(
                            onPressed: () => _unlink(identity),
                            child: Text(tr('Отвязать', 'Ҷудо')),
                          )
                        : null,
                  ),
                if (canChange) ...[
                  const SizedBox(height: 8),
                  for (final entry in unlinkedProviders)
                    _disabledAwareButton(
                      enabled: entry.value.enabled,
                      onPressed: () => _linkOAuth(entry.value.provider),
                      label: tr('Привязать ${entry.value.title}', 'Пайваст кардани ${entry.value.title}'),
                      soonLabel: tr('Привязать ${entry.value.title} (скоро)', 'Пайваст кардани ${entry.value.title} (наздик)'),
                    ),
                  if (!linked.contains('email'))
                    OutlinedButton(
                      onPressed: _linkEmail,
                      child: Text(tr('Привязать почту', 'Пайваст кардани почта')),
                    ),
                  if (!linked.contains('phone')) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _linkPhone,
                      child: Text(tr('Привязать телефон', 'Пайваст кардани телефон')),
                    ),
                  ],
                ],
                if (!canChange)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr(
                        'Не удалось проверить аккаунт. Закройте шторку и откройте её снова.',
                        'Санҷиши ҳисоб нашуд. Варақаро пӯшед ва аз нав кушоед.',
                      ),
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
              ],
              if (_info != null) ...[
                const SizedBox(height: 10),
                Text(_info!, style: TextStyle(color: AppColors.primary)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _labelFor(String provider) {
    switch (provider) {
      case 'email':
        return tr('Почта', 'Почта');
      case 'phone':
        return tr('Телефон', 'Телефон');
      default:
        return provider;
    }
  }

  String _subtitleFor(UserIdentity identity) {
    if (identity.provider == 'phone') {
      return identity.identityData?['phone'] as String? ?? '';
    }
    return identity.identityData?['email'] as String? ?? '';
  }

  Widget _disabledAwareButton({
    required bool enabled,
    required VoidCallback onPressed,
    required String label,
    required String soonLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: Text(enabled ? label : soonLabel),
        ),
      ),
    );
  }
}

class _ProviderInfo {
  const _ProviderInfo(this.title, this.provider, {required this.enabled});

  final String title;
  final OAuthProvider provider;
  final bool enabled;
}
