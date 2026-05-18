import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Background (spec: #050505 ~ #0B0B0D)
  static const black = Color(0xFF050505);
  static const background = black;
  static const blackElevated = Color(0xFF0B0B0D);

  // Card surfaces (spec: #111111 / #151515)
  static const card = Color(0xFF111111);
  static const cardElevated = Color(0xFF151515);

  static const white = Color(0xFFFFFFFF);
  static const textPrimary = white;

  // Text hierarchy
  static const textSubtle = Color.fromRGBO(255, 255, 255, 0.65);
  static const textInactive = Color.fromRGBO(255, 255, 255, 0.45);

  // Borders (spec: rgba(255,255,255,0.08))
  static const border = Color.fromRGBO(255, 255, 255, 0.08);
  static const border2 = Color.fromRGBO(255, 255, 255, 0.12);

  // Accent (spec: #FF6B00 / #FF7A00 / #FF8A00)
  static const orange = Color(0xFFFF6B00);
  static const orangeAccent = Color(0xFFFF7A00);
  static const orangeHighlight = Color(0xFFFF8A00);

  // Neutral helpers (used by placeholders)
  static const gray = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.orange,
        secondary: AppColors.gray,
        surface: AppColors.cardElevated,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.white,
        displayColor: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardElevated.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.black,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.orange : AppColors.white,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.orange : AppColors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
