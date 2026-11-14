import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Карточка ввода кода из письма: анимированные ячейки, проверка, успех и ошибка.
/// onVerify возвращает null, если код верный, или текст ошибки.
class OtpCodeView extends StatefulWidget {
  const OtpCodeView({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResend,
    required this.onChangeEmail,
    this.codeLength = 6,
  });

  final String email;
  final Future<String?> Function(String code) onVerify;
  final Future<String?> Function() onResend;
  final VoidCallback onChangeEmail;
  final int codeLength;

  @override
  State<OtpCodeView> createState() => _OtpCodeViewState();
}

enum _Phase { idle, verifying, success, error }

class _OtpCodeViewState extends State<OtpCodeView> with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  _Phase _phase = _Phase.idle;
  String? _error;
  int _cooldown = 30;
  Timer? _timer;

  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
    _startCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _shake.dispose();
    _ripple.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _onChanged() {
    if (_error != null && _phase == _Phase.idle) _error = null;
    setState(() {});
    if (_ctrl.text.length == widget.codeLength) _submit();
  }

  Future<void> _submit() async {
    final code = _ctrl.text.trim();
    if (code.length != widget.codeLength) return;
    if (_phase == _Phase.verifying || _phase == _Phase.success) return;
    setState(() {
      _phase = _Phase.verifying;
      _error = null;
    });
    final err = await widget.onVerify(code);
    if (!mounted) return;
    if (err == null) {
      setState(() => _phase = _Phase.success);
      _ripple.forward(from: 0);
      return;
    }
    setState(() {
      _phase = _Phase.error;
      _error = err;
    });
    await _shake.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _ctrl.clear();
    setState(() => _phase = _Phase.idle);
    _focus.requestFocus();
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final err = await widget.onResend();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _startCooldown();
    }
  }

  String get _mm => '0:${_cooldown.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final success = _phase == _Phase.success;
    final error = _phase == _Phase.error;
    final verifying = _phase == _Phase.verifying;
    final accent = error ? AppColors.ruby : (success ? AppColors.primary : AppColors.primary);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusIcon(accent, success, error, verifying),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              success
                  ? 'Вы подтверждены'
                  : (error ? 'Код не подошёл' : 'Подтвердите, что это вы'),
              key: ValueKey('t$success$error'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              success
                  ? 'Аккаунт подтверждён, сейчас откроем приложение'
                  : verifying
                      ? 'Проверяем код…'
                      : error
                          ? (_error ?? '')
                          : 'Введите код, который мы отправили на\n${widget.email}',
              key: ValueKey('s$_phase$_error'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: error ? AppColors.ruby : AppColors.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 26),
          _boxes(accent, error, success),
          const SizedBox(height: 22),
          _button(success, verifying),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Не пришёл код? ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              if (_cooldown > 0)
                Text(
                  'отправить снова через $_mm',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                )
              else
                TextButton(
                  onPressed: _resend,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                  child: const Text('отправить снова', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          TextButton(
            onPressed: widget.onChangeEmail,
            child: const Text('Изменить почту', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// Иконка сверху: замок → спиннер → зелёная галочка с волной.
  Widget _statusIcon(Color accent, bool success, bool error, bool verifying) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (success)
            AnimatedBuilder(
              animation: _ripple,
              builder: (_, __) => Container(
                width: 96 * (1 + _ripple.value * 0.35),
                height: 96 * (1 + _ripple.value * 0.35),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35 * (1 - _ripple.value)),
                    width: 3,
                  ),
                ),
              ),
            ),
          if (verifying)
            RotationTransition(
              turns: _spin,
              child: const SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: success ? AppColors.primary : accent.withValues(alpha: 0.12),
            ),
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final dx = error ? math.sin(_shake.value * math.pi * 4) * 6 * (1 - _shake.value) : 0.0;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: c,
                ),
                child: Icon(
                  success ? Icons.check_rounded : Icons.lock_rounded,
                  key: ValueKey(success),
                  size: 38,
                  color: success ? Colors.white : accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ячейки под код. Цифра «выскакивает», текущая ячейка подсвечена.
  Widget _boxes(Color accent, bool error, bool success) {
    final text = _ctrl.text;
    final focusIndex = text.length.clamp(0, widget.codeLength - 1);
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final dx = error ? math.sin(_shake.value * math.pi * 4) * 10 * (1 - _shake.value) : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            children: [
              for (var i = 0; i < widget.codeLength; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AspectRatio(
                      aspectRatio: 0.85,
                      child: _box(i, text, focusIndex, accent, error, success),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: widget.codeLength,
              autofillHints: const [AutofillHints.oneTimeCode],
              enabled: !success && !error,
              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _box(int i, String text, int focusIndex, Color accent, bool error, bool success) {
    final char = i < text.length ? text[i] : '';
    final focused = _focus.hasFocus && i == focusIndex && text.length < widget.codeLength;
    final borderColor = error
        ? AppColors.ruby
        : success
            ? AppColors.primary
            : focused
                ? AppColors.primary
                : const Color(0xFFE3ECE9);
    final fill = error
        ? AppColors.ruby.withValues(alpha: 0.08)
        : success
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: focused ? 2 : 1.4),
        boxShadow: focused
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      alignment: Alignment.center,
      child: char.isEmpty
          ? (focused
              ? const _BlinkCaret()
              : const SizedBox.shrink())
          : TweenAnimationBuilder<double>(
              key: ValueKey('$i$char'),
              tween: Tween(begin: 1.3, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: Text(
                char,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: error ? AppColors.ruby : (success ? AppColors.deep : AppColors.ink),
                ),
              ),
            ),
    );
  }

  Widget _button(bool success, bool verifying) {
    final ready = _ctrl.text.length == widget.codeLength;
    final enabled = ready && !verifying && !success;
    final colors = success
        ? [AppColors.primary, AppColors.primary]
        : [AppColors.primary, AppColors.deep];
    return GestureDetector(
      onTap: enabled ? _submit : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: (enabled || success || verifying) ? 1 : 0.45,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: verifying
                ? const Row(
                    key: ValueKey('v'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Проверяем…', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  )
                : success
                    ? const Row(
                        key: ValueKey('s'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Готово', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Text(
                        'Подтвердить',
                        key: ValueKey('i'),
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
          ),
        ),
      ),
    );
  }
}

/// Мигающий курсор в пустой ячейке.
class _BlinkCaret extends StatefulWidget {
  const _BlinkCaret();

  @override
  State<_BlinkCaret> createState() => _BlinkCaretState();
}

class _BlinkCaretState extends State<_BlinkCaret> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(width: 2, height: 26, color: AppColors.primary),
    );
  }
}
