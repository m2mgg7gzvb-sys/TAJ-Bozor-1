import 'package:flutter/material.dart';

/// Переход с плавным появлением без выезда: старый экран не сдвигается и не виден рядом.
PageRouteBuilder<T> fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    // Назад — сразу: главная появляется мгновенно, без задержки шапки.
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}
