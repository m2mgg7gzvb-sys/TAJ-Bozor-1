import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Регистрация и вход по почте.
/// Шаг 1: почта (и имя при регистрации) → Supabase присылает 6-значный код.
/// Шаг 2: код из письма → verifyOTP создаёт сессию.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _codeStep = false;
  bool _loading = false;
  String? _error;
  bool _isRegister = true;

  SupabaseClient get _db => Supabase.instance.client;

  /// Временный тестовый вход без почты (анонимный пользователь).
  /// Убрать, когда будет настроена почта и регистрация по коду.
  Future<void> _anonymousLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _db.auth.signInAnonymously();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось войти. Проверьте сеть');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(v);

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (_isRegister && name.length < 2) {
      setState(() => _error = 'Укажите имя');
      return;
    }
    if (!_validEmail(email)) {
      setState(() => _error = 'Проверьте почту');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _db.auth.signInWithOtp(
        email: email,
        shouldCreateUser: _isRegister,
        data: _isRegister ? {'name': name} : null,
      );
      setState(() => _codeStep = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось отправить код. Проверьте сеть');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введите 6 цифр из письма');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _db.auth.verifyOTP(
        type: OtpType.email,
        email: _emailCtrl.text.trim(),
        token: code,
      );
      // Успешный вход перехватит RootGate через onAuthStateChange.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Не удалось проверить код');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'TAJBozor',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _codeStep
                    ? 'Мы отправили 6-значный код на ${_emailCtrl.text.trim()}'
                    : 'Объявления Таджикистана в одном месте',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 32),
              if (!_codeStep) ...[
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Регистрация')),
                    ButtonSegment(value: false, label: Text('Вход')),
                  ],
                  selected: {_isRegister},
                  onSelectionChanged: (s) => setState(() {
                    _isRegister = s.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 20),
                if (_isRegister) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ваше имя',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Почта',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 8),
                  decoration: const InputDecoration(counterText: ''),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : (_codeStep ? _verifyCode : _sendCode),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(_codeStep ? 'Подтвердить' : 'Получить код на почту'),
              ),
              const SizedBox(height: 12),
              if (!_codeStep) ...[
                OutlinedButton(
                  onPressed: _loading ? null : _anonymousLogin,
                  child: const Text('Тестовый вход без почты'),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () {
                  if (_codeStep) {
                    setState(() {
                      _codeStep = false;
                      _codeCtrl.clear();
                      _error = null;
                    });
                  }
                },
                child: Text(_codeStep ? 'Изменить почту' : ''),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
