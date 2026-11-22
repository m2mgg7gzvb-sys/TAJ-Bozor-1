import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';
import 'theme.dart';

const _linkRedirect = 'https://app.tajbozor.pro';

/// Шторка «Способы входа»: что привязано к аккаунту и можно ли привязать ещё.
/// Привязывать может только основной аккаунт (самый первый зарегистрированный).
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

  Future<void> _link(OAuthProvider provider) async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.linkIdentity(provider, redirectTo: _linkRedirect);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr(
            'Не удалось привязать. Этот способ входа может уже принадлежать другому аккаунту.',
            'Пайваст карда нашуд. Ин роҳи воридшавӣ шояд ба ҳисоби дигар тааллуқ дорад.',
          ));
    }
  }

  Future<void> _unlink(UserIdentity identity) async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.unlinkIdentity(identity);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('Не удалось отвязать способ входа', 'Ҷудо кардани роҳ нашуд'));
      }
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
                    title: Text(_providers[identity.provider]?.title ?? identity.provider,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(identity.identityData?['email'] as String? ?? ''),
                    trailing: canChange && identities.length > 1
                        ? TextButton(
                            onPressed: () => _unlink(identity),
                            child: Text(tr('Отвязать', 'Ҷудо')),
                          )
                        : null,
                  ),
                if (unlinkedProviders.isNotEmpty && canChange) ...[
                  const SizedBox(height: 8),
                  for (final entry in unlinkedProviders)
                    Opacity(
                      opacity: entry.value.enabled ? 1 : 0.4,
                      child: OutlinedButton(
                        onPressed: entry.value.enabled ? () => _link(entry.value.provider) : null,
                        child: Text(
                          entry.value.enabled
                              ? tr('Привязать ${entry.value.title}', 'Пайваст кардани ${entry.value.title}')
                              : tr('Привязать ${entry.value.title} (скоро)', 'Пайваст кардани ${entry.value.title} (наздик)'),
                        ),
                      ),
                    ),
                ],
                if (!canChange)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr(
                        'Привязывать и отвязывать способы может только основной аккаунт (самый первый). Здесь можно только входить.',
                        'Танҳо ҳисоби асосӣ (аввалин) метавонад роҳҳоро пайваст ва ҷудо кунад.',
                      ),
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
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
}

class _ProviderInfo {
  const _ProviderInfo(this.title, this.provider, {required this.enabled});

  final String title;
  final OAuthProvider provider;
  final bool enabled;
}
