import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  // Semantic colors — same in light and dark
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color incomeColor = Color(0xFF0D9E4E);
  static const Color expenseColor = Color(0xFFD32F2F);
  static const Color savingsColor = Color(0xFF7B1FA2);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;


  // ── Theme-dependent colors (use via `AppTheme.xxx(context)`) ──

  // Surface / background colors
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1E1E1E);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF5F7FA)
          : const Color(0xFF121212);

  static Color chipBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF0F0F0)
          : const Color(0xFF2C2C2C);

  static Color filterBarBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1E1E1E);

  // Text colors
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFE0E0E0);

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF6B7280)
          : const Color(0xFF9E9E9E);

  // Grey-scale helpers
  static Color grey300(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFE0E0E0)
          : const Color(0xFF616161);

  static Color grey400(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFBDBDBD)
          : const Color(0xFF757575);

  static Color grey500(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF9E9E9E)
          : const Color(0xFF8E8E8E);

  // ── Theme data definitions ──

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      foregroundColor: Color(0xFF1A1A2E),
      backgroundColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      foregroundColor: Color(0xFFE0E0E0),
      backgroundColor: Color(0xFF1E1E1E),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: const Color(0xFF1E1E1E),
      indicatorColor: primaryColor.withValues(alpha: 0.20),
    ),
  );

  // ── Utilities ──

  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
