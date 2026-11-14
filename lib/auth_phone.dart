import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Вход по номеру +992: сначала номер, потом код из SMS.
/// Работает, когда в Supabase подключён SMS-провайдер (см. инструкцию).
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, this.register = false});

  /// true — регистрация (аккаунт создастся), false — вход (аккаунта может не быть).
  final bool register;

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeStep = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String get _digits => _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _sendCode() async {
    if (_digits.length != 9) {
      setState(() => _error = 'Введите 9 цифр номера');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        phone: '+992$_digits',
        shouldCreateUser: widget.register,
      );
      if (mounted) setState(() => _codeStep = true);
    } on AuthException catch (e) {
      final notFound = e.message.toLowerCase().contains('signups not allowed') ||
          e.message.toLowerCase().contains('signup');
      if (mounted) {
        setState(() => _error = !widget.register && notFound
            ? 'Аккаунта с этим номером нет. Зарегистрируйтесь'
            : 'Не удалось отправить код. Проверьте номер и попробуйте позже');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось отправить код. Проверьте номер и попробуйте позже');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        phone: '+992$_digits',
        token: _codeCtrl.text.trim(),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Неверный код. Попробуйте ещё раз');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Вход по номеру',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.deep),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_codeStep) ...[
                const Text('Номер телефона', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Пришлём код в SMS', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3ECE9)),
                      ),
                      child: const Text('+992', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '90 000 00 00',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Введите код', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Код отправлен на +992$_digits', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6 цифр из SMS',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.ruby)),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : (_codeStep ? _verify : _sendCode),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_codeStep ? 'Войти' : 'Получить код'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
