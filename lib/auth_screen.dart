import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _isRegister = false;

  SupabaseClient get _db => Supabase.instance.client;

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
      final notFound = e.message.toLowerCase().contains('signups not allowed') ||
          e.message.toLowerCase().contains('signup');
      setState(() => _error = !_isRegister && notFound
          ? 'Аккаунта с этой почтой нет. Нажмите «Нет аккаунта? Зарегистрироваться» ниже'
          : e.message);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                _codeStep ? 'Введите код' : (_isRegister ? 'Регистрация' : 'Вход'),
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _codeStep
                    ? 'Мы отправили 6-значный код на ${_emailCtrl.text.trim()}'
                    : 'Войдите по почте, код придёт на письмо',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (!_codeStep) ...[
                if (_isRegister)
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
                  ),
                if (_isRegister) const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Почта', border: OutlineInputBorder()),
                ),
              ] else ...[
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 6),
                  decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : (_codeStep ? _verifyCode : _sendCode),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_codeStep ? 'Подтвердить' : 'Получить код на почту'),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              if (!_codeStep)
                TextButton(
                  onPressed: () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
                  child: Text(_isRegister ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
                )
              else
                TextButton(
                  onPressed: () => setState(() {
                    _codeStep = false;
                    _codeCtrl.clear();
                    _error = null;
                  }),
                  child: const Text('Изменить почту'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
