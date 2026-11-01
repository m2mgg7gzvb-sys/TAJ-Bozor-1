import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';

/// Перестраивает приложение при входе и выходе пользователя.
/// Конструктор HomeShell не const, чтобы вкладка «Войти» обновлялась после смены сессии.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) => HomeShell(key: UniqueKey()),
    );
  }
}
