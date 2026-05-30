import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 主题标识
enum AppThemeId { claude, auroraBlue, obsidian }

/// 调色板：一套主题的全部颜色 token + ThemeData 构造
class AppPalette {
  final AppThemeId id;
  final String name;
  final Brightness brightness;

  // Primary
  final Color primaryColor;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;

  // Backgrounds
  final Color bgScaffold;
  final Color bgCard;
  final Color bgSurface;
  final Color bgInput;
  final Color bgHover;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  // Status
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Border
  final Color borderSubtle;
  final Color borderFocus;

  // Chat bubble user background
  final Color chatUserBg;

  // Gradient soft 端点
  final Color softGradientStart;
  final Color softGradientEnd;

  // Primary 按钮/FAB 前景色
  final Color onPrimary;

  const AppPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.primaryColor,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.bgScaffold,
    required this.bgCard,
    required this.bgSurface,
    required this.bgInput,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.borderSubtle,
    required this.borderFocus,
    required this.chatUserBg,
    required this.softGradientStart,
    required this.softGradientEnd,
    this.onPrimary = Colors.white,
  });

  // ---- Claude（默认，暖珊瑚色 亮色）----
  static const AppPalette claude = AppPalette(
    id: AppThemeId.claude,
    name: 'Claude 暖珊瑚',
    brightness: Brightness.light,
    primaryColor: Color(0xFFC15F3C),
    primaryLight: Color(0xFFD47A5A),
    primaryDark: Color(0xFFA84A2A),
    accent: Color(0xFFE8B89D),
    bgScaffold: Color(0xFFF5F5F0),
    bgCard: Color(0xFFFFFFFF),
    bgSurface: Color(0xFFFFFFFF),
    bgInput: Color(0xFFF0EFEB),
    bgHover: Color(0xFFEAE9E4),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    textHint: Color(0xFF9C9C9C),
    success: Color(0xFF2D9D5E),
    warning: Color(0xFFD4952E),
    error: Color(0xFFD13B3B),
    info: Color(0xFF4A8FC1),
    borderSubtle: Color(0xFFE5E4DF),
    borderFocus: Color(0xFFC15F3C),
    chatUserBg: Color(0xFFFEF0EA),
    softGradientStart: Color(0xFFF5F0EB),
    softGradientEnd: Color(0xFFFFFFFF),
  );

  // ---- 极光蓝（Google Material 3）----
  static const AppPalette auroraBlue = AppPalette(
    id: AppThemeId.auroraBlue,
    name: '极光蓝 Material 3',
    brightness: Brightness.light,
    primaryColor: Color(0xFF1A73E8),
    primaryLight: Color(0xFF4285F4),
    primaryDark: Color(0xFF1557B0),
    accent: Color(0xFFA8C7FA),
    bgScaffold: Color(0xFFF8F9FC),
    bgCard: Color(0xFFFFFFFF),
    bgSurface: Color(0xFFFFFFFF),
    bgInput: Color(0xFFEEF1F6),
    bgHover: Color(0xFFE6EBF4),
    textPrimary: Color(0xFF1A1C1E),
    textSecondary: Color(0xFF5F6368),
    textHint: Color(0xFF9AA0A6),
    success: Color(0xFF1E8E3E),
    warning: Color(0xFFE37400),
    error: Color(0xFFD93025),
    info: Color(0xFF1A73E8),
    borderSubtle: Color(0xFFE0E3E9),
    borderFocus: Color(0xFF1A73E8),
    chatUserBg: Color(0xFFE8F0FE),
    softGradientStart: Color(0xFFEFF3FB),
    softGradientEnd: Color(0xFFFFFFFF),
  );

  // ---- 曜石黑（深色模式）----
  static const AppPalette obsidian = AppPalette(
    id: AppThemeId.obsidian,
    name: '曜石黑 深色',
    brightness: Brightness.dark,
    primaryColor: Color(0xFF3B82F6),
    primaryLight: Color(0xFF60A5FA),
    primaryDark: Color(0xFF2563EB),
    accent: Color(0xFF1E3A5F),
    bgScaffold: Color(0xFF0E0F11),
    bgCard: Color(0xFF1A1B1E),
    bgSurface: Color(0xFF1A1B1E),
    bgInput: Color(0xFF26282C),
    bgHover: Color(0xFF2E3035),
    textPrimary: Color(0xFFECECEC),
    textSecondary: Color(0xFFA0A0A8),
    textHint: Color(0xFF6B6E76),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    borderSubtle: Color(0xFF2C2E33),
    borderFocus: Color(0xFF3B82F6),
    chatUserBg: Color(0xFF1E293B),
    softGradientStart: Color(0xFF1A1B1E),
    softGradientEnd: Color(0xFF0E0F11),
    onPrimary: Colors.white,
  );

  static const List<AppPalette> all = [claude, auroraBlue, obsidian];

  static AppPalette byId(AppThemeId id) =>
      all.firstWhere((p) => p.id == id, orElse: () => claude);

  bool get isDark => brightness == Brightness.dark;

  TextTheme _buildTextTheme() {
    return GoogleFonts.interTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: textPrimary),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: textPrimary),
        displaySmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textPrimary, fontFamily: 'Instrument Serif'),
        headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: textHint, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textHint),
      ),
    );
  }

  ThemeData build() {
    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primaryColor,
            secondary: primaryLight,
            surface: bgCard,
            error: error,
            onPrimary: onPrimary,
            onSecondary: onPrimary,
            onSurface: textPrimary,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: primaryColor,
            secondary: primaryLight,
            surface: bgCard,
            error: error,
            onPrimary: onPrimary,
            onSecondary: onPrimary,
            onSurface: textPrimary,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: bgScaffold,
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: bgCard,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: primaryColor,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderSubtle, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textHint, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: borderSubtle,
        thickness: 0.5,
        space: 0,
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: BorderSide(color: textHint, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderSubtle, width: 0.5),
        ),
        elevation: 2,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? bgInput : textPrimary,
        contentTextStyle: TextStyle(color: isDark ? textPrimary : Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: bgInput,
        selectedColor: primaryColor.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: textPrimary, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: primaryColor, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderSubtle, width: 0.5),
        ),
      ),
    );
  }
}

/// 全局主题门面：对外 API 名称保持不变，内部委托当前调色板。
class AppTheme {
  AppTheme._();

  static AppPalette _current = AppPalette.claude;

  static AppPalette get current => _current;
  static AppThemeId get currentId => _current.id;

  /// 切换调色板（不负责持久化/通知，由 ThemeController 调用）
  static void setPalette(AppThemeId id) {
    _current = AppPalette.byId(id);
  }

  // ---- 颜色 token：static const -> static get（委托当前调色板）----
  static Color get primaryColor => _current.primaryColor;
  static Color get primaryLight => _current.primaryLight;
  static Color get primaryDark => _current.primaryDark;
  static Color get accent => _current.accent;

  static Color get bgScaffold => _current.bgScaffold;
  static Color get bgCard => _current.bgCard;
  static Color get bgSurface => _current.bgSurface;
  static Color get bgInput => _current.bgInput;
  static Color get bgHover => _current.bgHover;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textHint => _current.textHint;

  static Color get success => _current.success;
  static Color get warning => _current.warning;
  static Color get error => _current.error;
  static Color get info => _current.info;

  static Color get borderSubtle => _current.borderSubtle;
  static Color get borderFocus => _current.borderFocus;

  static Color get chatUserBg => _current.chatUserBg;

  // ---- 优先级颜色：语义固定，跨主题不变 ----
  static const Color priorityP0 = Color(0xFFD13B3B);
  static const Color priorityP1 = Color(0xFFD4952E);
  static const Color priorityP2 = Color(0xFF2D9D5E);
  static const Color priorityP3 = Color(0xFF4A8FC1);

  // ---- Shadows ----
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: _current.isDark ? 0.30 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowLight => [
        BoxShadow(
          color: Colors.black.withValues(alpha: _current.isDark ? 0.20 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: _current.primaryColor.withValues(alpha: 0.25),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  // ---- Gradients ----
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [_current.primaryColor, _current.primaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get softGradient => LinearGradient(
        colors: [_current.softGradientStart, _current.softGradientEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  // ---- ThemeData ----
  static ThemeData get themeData => _current.build();

  /// 向后兼容旧引用
  static ThemeData get lightTheme => _current.build();
}
