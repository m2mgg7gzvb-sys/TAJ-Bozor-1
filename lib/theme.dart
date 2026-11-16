import 'package:flutter/material.dart';

/// Тёмная тема включена (переключается в профиле и хранится в аккаунте).
final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);

/// Фирменные цвета TAJBozor (из макета). Нейтральные цвета меняются в тёмной теме.
class AppColors {
  static const primary = Color(0xFF0E7C66);
  static const deep = Color(0xFF0A5C4B);
  static const saffron = Color(0xFFF5A524);
  static const ruby = Color(0xFFD62D4A);

  static bool get _dark => darkMode.value;

  static Color get ink => _dark ? Colors.white : const Color(0xFF0B1F1A);
  /// Заголовки и акцентный текст: белый в тёмной теме, тёмно-зелёный в светлой.
  static Color get title => _dark ? Colors.white : deep;
  static Color get background => _dark ? const Color(0xFF0C1513) : const Color(0xFFF4F7F6);
  static Color get mint => _dark ? const Color(0xFF16302A) : const Color(0xFFEAF2EF);
  static Color get muted => _dark ? const Color(0xFFD2E0DB) : const Color(0xFF5C6F68);

  /// Поверхность карточек и полей (белая в светлой теме).
  static Color get surface => _dark ? const Color(0xFF15221F) : Colors.white;
  static Color get line => _dark ? const Color(0xFF26403A) : const Color(0xFFE3ECE9);
}

/// Светлая или тёмная тема в одной сборке. Вызывается при каждом построении MaterialApp.
ThemeData buildAppTheme({bool dark = false}) {
  final bg = dark ? const Color(0xFF0C1513) : const Color(0xFFF4F7F6);
  final ink = dark ? Colors.white : const Color(0xFF0B1F1A);
  final muted = dark ? const Color(0xFFD2E0DB) : const Color(0xFF5C6F68);
  final mint = dark ? const Color(0xFF16302A) : const Color(0xFFEAF2EF);
  final surface = dark ? const Color(0xFF15221F) : Colors.white;
  final line = dark ? const Color(0xFF26403A) : const Color(0xFFE3ECE9);

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: AppColors.primary,
    surface: surface,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    // Без волны-подсветки при нажатии: реакция кнопок мгновенная.
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: mint,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.primary : muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: surface,
        selectedBackgroundColor: mint,
        selectedForegroundColor: dark ? const Color(0xFFBFE8DC) : AppColors.deep,
        side: BorderSide(color: line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    // Всплывающие уведомления в фирменном стиле: тёмно-зелёная плашка с золотой каймой.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.deep,
      elevation: 0,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      actionTextColor: const Color(0xFFFFE08A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x88E0A526)),
      ),
    ),
  );
}

/// Тёмная тема (тот же стиль, что и светлая).
ThemeData buildDarkTheme() => buildAppTheme(dark: true);

/// Карточка с мягкой тенью (белая в светлой теме, тёмно-зелёная в тёмной).
BoxDecoration cardDecoration({double radius = 20}) => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B1F1A).withValues(alpha: 0.06),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 10),
        ),
      ],
    );
