import 'package:flutter/material.dart';

class AppTheme {
  // Claude-inspired Warm Dark Palette
  static const Color primaryColor = Color(0xFFC15F3C);    // Crail orange
  static const Color primaryLight = Color(0xFFD47A5A);
  static const Color primaryDark = Color(0xFFA84A2A);

  // Backgrounds
  static const Color bgScaffold = Color(0xFF1A1A2E);
  static const Color bgCard = Color(0xFF1E1E2E);
  static const Color bgInput = Color(0xFF252536);
  static const Color bgSurface = Color(0xFF222236);

  // Text
  static const Color textPrimary = Color(0xFFEAEAEA);
  static const Color textSecondary = Color(0xFFB1ADA1);
  static const Color textHint = Color(0xFF6B6B7B);

  // Priority Colors
  static const Color priorityP0 = Color(0xFFE53935);
  static const Color priorityP1 = Color(0xFFFF9800);
  static const Color priorityP2 = Color(0xFF43A047);
  static const Color priorityP3 = Color(0xFF42A5F5);

  // Status Colors
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF42A5F5);

  // Border
  static const Color borderSubtle = Color(0xFF2D2D3F);

  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primaryColor, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgScaffold,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: primaryLight,
        surface: bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderSubtle, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        bodySmall: TextStyle(fontSize: 12, color: textHint),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 0.5),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: textHint, width: 1.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
