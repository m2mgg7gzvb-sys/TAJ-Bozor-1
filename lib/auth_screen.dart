import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'otp_code_view.dart';
import 'theme.dart';

/// Регистрация и вход по почте.
/// Шаг 1: почта (и имя при регистрации) → Supabase присылает 6-значный код.
/// Шаг 2: код из письма → verifyOTP создаёт сессию.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startRegister = false});

  /// true — открыть сразу регистрацию.
  final bool startRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _codeStep = false;
  bool _loading = false;
  String? _error;
  bool _isRegister = false;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.startRegister;
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

  /// Проверяет код из письма. Возвращает null, если код верный, иначе текст ошибки.
  Future<String?> _verifyCode(String code) async {
    try {
      await _db.auth.verifyOTP(
        type: OtpType.email,
        email: _emailCtrl.text.trim(),
        token: code,
      );
      // Успешный вход перехватит экран приветствия или RootGate через onAuthStateChange.
      return null;
    } on AuthException {
      return 'Код неверный или устарел. Попробуйте ещё раз';
    } catch (_) {
      return 'Не удалось проверить код. Проверьте сеть';
    }
  }

  /// Отправляет код повторно. Возвращает null при успехе.
  Future<String?> _resendCode() async {
    try {
      await _db.auth.signInWithOtp(
        email: _emailCtrl.text.trim(),
        shouldCreateUser: _isRegister,
        data: _isRegister ? {'name': _nameCtrl.text.trim()} : null,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Не удалось отправить код. Проверьте сеть';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_codeStep) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F7F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F7F5),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: OtpCodeView(
              email: _emailCtrl.text.trim(),
              onVerify: _verifyCode,
              onResend: _resendCode,
              onChangeEmail: () => setState(() {
                _codeStep = false;
                _error = null;
              }),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                _isRegister ? 'Регистрация' : 'Вход',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Войдите по почте, код придёт на письмо',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (_isRegister) ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Имя'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Почта'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _loading ? null : _sendCode,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Получить код на почту'),
              ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  _isRegister = !_isRegister;
                  _error = null;
                }),
                child: Text(_isRegister ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
