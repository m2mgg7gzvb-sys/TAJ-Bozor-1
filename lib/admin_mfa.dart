import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'lang_store.dart';
import 'theme.dart';

/// Открывает админский экран только после второго фактора (код из приложения-аутентификатора).
Future<void> openAdminScreen(BuildContext context, Widget screen) async {
  final ok = await ensureAdminMfa(context);
  if (!ok || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// true, если сессия уже с кодом. Иначе — подключение или ввод кода.
Future<bool> ensureAdminMfa(BuildContext context) async {
  final mfa = Supabase.instance.client.auth.mfa;
  try {
    final aal = await mfa.getAuthenticatorAssuranceLevel();
    if (aal.currentLevel.toString().contains('aal2')) return true;
    final factors = await mfa.listFactors();
    final verified = factors.totp.where((f) => f.status.toString().contains('verified')).toList();
    if (!context.mounted) return false;
    if (verified.isEmpty) {
      final done = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const _EnrollScreen()));
      return done ?? false;
    }
    final done = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => _VerifyScreen(factorId: verified.first.id)));
    return done ?? false;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось проверить вход администратора', 'Санҷиши воридшавии администратор муяссар нашуд'))),
      );
    }
    return false;
  }
}

class _VerifyScreen extends StatefulWidget {
  const _VerifyScreen({required this.factorId});

  final String factorId;

  @override
  State<_VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<_VerifyScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(factorId: widget.factorId, code: code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr('Неверный код. Попробуйте ещё раз', 'Рамзи нодуруст. Боз кӯшиш кунед');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr('Код администратора', 'Рамзи администратор'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Введите 6-значный код из приложения-аутентификатора.',
                'Рамзи 6-рақамиро аз барномаи аутентификатор ворид кунед.')),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('Войти', 'Ворид шудан')),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollScreen extends StatefulWidget {
  const _EnrollScreen();

  @override
  State<_EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<_EnrollScreen> {
  final _code = TextEditingController();
  String? _factorId;
  String? _secret;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    try {
      final res = await Supabase.instance.client.auth.mfa
          .enroll(factorType: FactorType.totp, friendlyName: 'admin-${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      setState(() {
        _factorId = res.id;
        _secret = res.totp?.secret;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = tr('Не удалось создать код. Попробуйте позже', 'Эҷоди рамз муяссар нашуд'));
      }
    }
  }

  Future<void> _confirm() async {
    final id = _factorId;
    final code = _code.text.trim();
    if (id == null || code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(factorId: id, code: code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = tr('Неверный код. Попробуйте ещё раз', 'Рамзи нодуруст. Боз кӯшиш кунед');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr('Защита администратора', 'Ҳифзи администратор'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr(
            'Добавьте ключ в приложение-аутентификатор (Google Authenticator и подобные) и введите код, который оно покажет.',
            'Калидро ба барномаи аутентификатор илова кунед (Google Authenticator ва монанди он) ва рамзеро, ки нишон медиҳад, ворид кунед.',
          )),
          const SizedBox(height: 16),
          if (_secret != null) ...[
            Text(tr('Ключ для ввода вручную:', 'Калид барои ворид кардани дастӣ:'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            SelectableText(_secret!, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
            const SizedBox(height: 16),
          ] else if (_error == null)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: tr('Код из приложения', 'Рамз аз барнома'),
              counterText: '',
            ),
            onSubmitted: (_) => _confirm(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_factorId == null || _busy) ? null : _confirm,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('Подтвердить', 'Тасдиқ кардан')),
          ),
        ],
      ),
    );
  }
}
