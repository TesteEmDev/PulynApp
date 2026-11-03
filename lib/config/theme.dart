import 'package:flutter/material.dart';

// 🎨 Cores Pulyn (replicadas do Tailwind web)
class PulynColors {
  // Primary (Cyan/Blue) - #1E9BD7
  static const Color primary = Color(0xFF1E9BD7);
  static const Color primaryLight = Color(0xFF29B6F6);
  
  // Secondary (Green) - #4CAF50
  static const Color secondary = Color(0xFF4CAF50);
  
  // Accent (Orange) - #F5A623
  static const Color accent = Color(0xFFF5A623);
  
  // Pink - #E91E8C
  static const Color pink = Color(0xFFE91E8C);
  
  // Modo claro: quando true, as cores de superfície e texto mudam (ver os getters abaixo).
  // O nome "dark" é mantido por compatibilidade: estas cores são as de fundo, cartão e borda do tema atual.
  static bool claro = false;

  static Color get dark => claro ? const Color(0xFFF4F7FB) : const Color(0xFF0D1B2A);
  static Color get darkCard => claro ? const Color(0xFFFFFFFF) : const Color(0xFF132338);
  static Color get darkSurface => claro ? const Color(0xFFEEF3F9) : const Color(0xFF1A2F45);
  static Color get darkHover => claro ? const Color(0xFFE3EBF5) : const Color(0xFF1E3A54);
  static Color get darkBorder => claro ? const Color(0xFFD5DEEA) : const Color(0xFF1E3A54);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE53935);
  static const Color info = Color(0xFF1E9BD7);

  // Text colors
  static Color get textPrimary => claro ? const Color(0xFF1A2233) : Colors.white;
  static Color get textSecondary => claro ? const Color(0xFF4A5566) : const Color(0xFFA0A0A0);
  static Color get textMuted => claro ? const Color(0xFF6B7784) : const Color(0xFF6B7280);
}

/// Tema atual (conforme PulynColors.claro). Mantido para quem ainda usa `appTheme`.
ThemeData get appTheme => construirTema();

/// Tema do app, montado conforme o modo escolhido (PulynColors.claro).
ThemeData construirTema() {
  final claro = PulynColors.claro;
  return _construirTemaBase(claro);
}

ThemeData _construirTemaBase(bool claro) {
  final esquema = claro
      ? ColorScheme.light(
          primary: PulynColors.primary,
          secondary: PulynColors.secondary,
          tertiary: PulynColors.accent,
          surface: PulynColors.darkSurface,
          onSurface: PulynColors.textPrimary,
          error: PulynColors.danger,
        )
      : ColorScheme.dark(
          primary: PulynColors.primary,
          secondary: PulynColors.secondary,
          tertiary: PulynColors.accent,
          surface: PulynColors.darkSurface,
          onSurface: PulynColors.textPrimary,
          error: PulynColors.danger,
        );
  return ThemeData(
  useMaterial3: true,
  brightness: claro ? Brightness.light : Brightness.dark,
  scaffoldBackgroundColor: PulynColors.dark,
  colorScheme: esquema,
  appBarTheme: AppBarTheme(
    backgroundColor: PulynColors.dark,
    foregroundColor: PulynColors.textPrimary,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: PulynColors.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  cardTheme: CardThemeData(
    color: PulynColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: PulynColors.darkBorder,
        width: 1,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: PulynColors.darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: PulynColors.darkBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: PulynColors.darkBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: PulynColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: PulynColors.danger),
    ),
    labelStyle: TextStyle(color: PulynColors.textSecondary),
    hintStyle: TextStyle(color: PulynColors.textMuted),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: PulynColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: PulynColors.primary,
      side: BorderSide(color: PulynColors.darkBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: PulynColors.primary,
    ),
  ),
  textTheme: TextTheme(
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: PulynColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: PulynColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: PulynColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: PulynColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: PulynColors.textSecondary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: PulynColors.textMuted,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: PulynColors.darkCard,
    selectedItemColor: PulynColors.primary,
    unselectedItemColor: PulynColors.textMuted,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
  ),
  );
}
