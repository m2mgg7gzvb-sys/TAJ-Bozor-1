import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Пишет необработанные ошибки приложения в таблицу app_errors.
/// Не более 20 записей за сессию, одинаковые ошибки не повторяются. Сбой записи молча игнорируется.
class ErrorLog {
  ErrorLog._();

  static int _sent = 0;
  static final _seen = <String>{};

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(report('flutter', details.exceptionAsString(), details.stack));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report('platform', error.toString(), stack));
      return true;
    };
  }

  static Future<void> report(String source, String message, StackTrace? stack) async {
    if (_sent >= 20) return;
    final key = '$source|${message.length > 200 ? message.substring(0, 200) : message}';
    if (!_seen.add(key)) return;
    _sent++;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('app_errors').insert({
        'user_id': uid,
        'source': source,
        'message': message.length > 2000 ? message.substring(0, 2000) : message,
        'stack': stack == null ? null : '$stack'.substring(0, stack.toString().length > 4000 ? 4000 : stack.toString().length),
      });
    } catch (_) {
      // Журнал ошибок не должен сам ломать приложение.
    }
  }
}
