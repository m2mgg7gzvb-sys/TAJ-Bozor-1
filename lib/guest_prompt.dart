import 'package:flutter/material.dart';

import 'nav_state.dart';
import 'theme.dart';

/// Большой экран для гостя: иконка, заголовок, текст и кнопка входа.
class GuestPrompt extends StatelessWidget {
  const GuestPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.showButton = true,
  });

  final IconData icon;
  final String title;
  final String text;

  /// Кнопка «Войти в профиль». Для вошедшего пользователя её скрывают.
  final bool showButton;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(icon, size: 60, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.muted, height: 1.4),
            ),
            if (showButton) ...[
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => tabIndex.value = loginTabIndex,
                child: const Text('Войти в профиль'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
