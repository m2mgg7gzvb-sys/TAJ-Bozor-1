import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_choice.dart';
import 'lang_store.dart';
import 'telegram_login.dart';
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

  bool? _tgLinked;
  List<Map<String, dynamic>> _linkedAccounts = const [];

  @override
  void initState() {
    super.initState();
    _checkPrimary();
    _loadTelegram();
    _loadLinkedAccounts();
  }

  Future<void> _loadTelegram() async {
    try {
      final row = await Supabase.instance.client
          .from('telegram_links')
          .select('telegram_id')
          .maybeSingle();
      if (mounted) setState(() => _tgLinked = row != null);
    } catch (_) {
      if (mounted) setState(() => _tgLinked = false);
    }
  }

  Future<void> _linkTelegram() async {
    setState(() => _error = null);
    await startTelegramLink(context);
    await _loadTelegram();
  }

  /// Связанные аккаунты (привязка через «Привязать аккаунт») — показываем, с каким аккаунтом связан этот.
  Future<void> _loadLinkedAccounts() async {
    try {
      final res = await Supabase.instance.client.functions.invoke('account-link', body: {'action': 'links'});
      final list = (res.data as Map<String, dynamic>?)?['accounts'] as List? ?? const [];
      final me = Supabase.instance.client.auth.currentUser?.id;
      final others = list.cast<Map<String, dynamic>>().where((a) => a['id'] != me).toList();
      if (mounted) setState(() => _linkedAccounts = others);
    } catch (_) {
      // Без списка связанных аккаунтов шторка работает как раньше
    }
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

  /// Привязка другого аккаунта по его почте. Чтобы доказать, что аккаунт ваш, приходит код на его почту.
  /// Потом приложение возвращает исходный аккаунт обратно.
  Future<void> _linkAccount() async {
    final client = Supabase.instance.client;
    final myRefresh = client.auth.currentSession?.refreshToken;
    if (myRefresh == null) return;
    final email = await _askText(
      title: tr('Привязать аккаунт', 'Пайваст кардани ҳисоб'),
      hint: tr('почта другого аккаунта', 'почтаи ҳисоби дигар'),
      keyboard: TextInputType.emailAddress,
    );
    if (email == null || email.isEmpty) return;

    accountLinkingBusy = true;
    String? error;
    try {
      final start = await client.functions.invoke('account-link', body: {'action': 'start'});
      final pendingId = (start.data as Map<String, dynamic>)['pending_id'] as String;

      await client.auth.signInWithOtp(email: email, shouldCreateUser: false);
      if (!mounted) return;
      final code = await _askText(
        title: tr('Код из письма', 'Рамз аз мактуб'),
        hint: '123456',
        keyboard: TextInputType.number,
      );
      if (code != null && code.isNotEmpty) {
        try {
          // Теперь сессия — это привязываемый аккаунт; он подтверждает связь.
          await client.auth.verifyOTP(type: OtpType.email, email: email, token: code);
          await client.functions.invoke('account-link', body: {'action': 'confirm', 'pending_id': pendingId});
          error = null;
        } on FunctionException catch (e) {
          error = e.status == 409
              ? tr(
                  'Этот аккаунт уже связан с другим или сам является главным для другого',
                  'Ин ҳисоб аллакай бо дигаре пайваст аст',
                )
              : tr('Не удалось привязать аккаунт', 'Пайвасти ҳисоб нашуд');
        } catch (_) {
          error = tr('Неверный код или ссылка устарела', 'Рамз нодуруст аст ё мўҳлат гузаштааст');
        } finally {
          // Возвращаем исходный аккаунт
          await client.auth.setSession(myRefresh);
        }
      } else {
        error = null;
      }
    } catch (_) {
      error = tr('Не удалось отправить код на эту почту', 'Рамз ба ин почта фиристода нашуд');
    } finally {
      accountLinkingBusy = false;
    }

    if (!mounted) return;
    if (error != null) {
      _fail(error);
    } else {
      setState(() {});
      _ok(tr(
        'Аккаунт привязан. При входе через его почту появится выбор, в какой войти.',
        'Ҳисоб пайваст шуд. Ҳангоми воридшавӣ тавассути почтаи он интихоб пайдо мешавад.',
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
                  'Способ входа открывает свой аккаунт. Связанные аккаунты переключаются через окно выбора при входе.',
                  'Роҳи воридшавӣ ҳисоби худро мекушояд. Ҳисобҳои пайвастшуда тавассути равзанаи интихоб иваз мешаванд.',
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
                if (_tgLinked == true)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
                    title: const Text('Telegram', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(tr('Привязан', 'Пайваст шуд')),
                  ),
                if (_linkedAccounts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(tr('Связанные аккаунты', 'Пайвастшуда ҳисобҳо'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final a in _linkedAccounts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_rounded, color: AppColors.primary),
                      title: Text((a['name'] as String?)?.trim().isNotEmpty == true
                          ? a['name'] as String
                          : tr('Пользователь', 'Корбар')),
                      subtitle: Text([
                        if ((a['public_id'] as String?)?.isNotEmpty == true) 'ID: ${a['public_id']}',
                      ].join('  ·  ')),
                    ),
                ],
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
                  if (_tgLinked == false) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _linkTelegram,
                      child: Text(tr('Привязать Telegram', 'Пайваст кардани Telegram')),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _linkAccount,
                    child: Text(tr('Привязать аккаунт', 'Пайваст кардани ҳисоб')),
                  ),
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
