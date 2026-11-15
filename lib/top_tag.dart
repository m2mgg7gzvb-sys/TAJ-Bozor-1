import 'package:flutter/material.dart';

import 'theme.dart';

/// Золотой значок «TOP» в стиле шапки главной: градиент и мягкое свечение.
class TopTag extends StatelessWidget {
  const TopTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0A526), Color(0xFFFFE08A), Color(0xFFE0A526)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE0A526).withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 0.5),
        ],
      ),
      child: Text(
        'TOP',
        style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
