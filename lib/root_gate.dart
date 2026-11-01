import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';

/// Перестраивает приложение при входе и выходе пользователя.
/// Ключ — id пользователя: при входе или выходе оболочка пересоздаётся, а при обновлении токена остаётся на месте.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) => HomeShell(
        key: ValueKey(Supabase.instance.client.auth.currentUser?.id),
      ),
    );
  }
}
