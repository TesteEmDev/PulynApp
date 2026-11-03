import 'package:flutter/material.dart';

// 🎨 Cores Pulyn (da logo: azul, verde, laranja, rosa)
class PulynColors {
  // Primary (azul da logo)
  static const Color primary = Color(0xFF1E9BD7);
  static const Color primaryLight = Color(0xFF29B6F6);

  // Secondary (verde da logo)
  static const Color secondary = Color(0xFF4CAF50);

  // Accent (laranja da logo)
  static const Color accent = Color(0xFFF5A623);

  // Pink (rosa da logo)
  static const Color pink = Color(0xFFE91E8C);

  // Modo claro: quando true, as cores de superfície e texto mudam (ver os getters abaixo).
  // O nome "dark" é mantido por compatibilidade: estas cores são as de fundo, cartão e borda do tema atual.
  static bool claro = false;

  static Color get dark => claro ? const Color(0xFFFAF8F5) : const Color(0xFF121214);
  static Color get darkCard => claro ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C20);
  static Color get darkSurface => claro ? const Color(0xFFF2EFEA) : const Color(0xFF26262B);
  static Color get darkHover => claro ? const Color(0xFFE8E3DC) : const Color(0xFF2E2E34);
  static Color get darkBorder => claro ? const Color(0xFFE6E1DA) : const Color(0xFF2E2E35);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE53935);
  static const Color info = Color(0xFF1E9BD7);

  // Text colors
  static Color get textPrimary => claro ? const Color(0xFF1F1B16) : Colors.white;
  static Color get textSecondary => claro ? const Color(0xFF5F5A53) : const Color(0xFFB4B2AE);
  static Color get textMuted => claro ? const Color(0xFF8A847C) : const Color(0xFF7D7B77);
}

/// Medidas padronizadas: botões, campos e cartões usam sempre estes valores.
class PulynMedidas {
  static const double raioBotao = 14;
  static const double raioCampo = 14;
  static const double raioCartao = 18;
  static const double alturaBotao = 54;
  static const double alturaCampo = 56;
  static const EdgeInsets paddingCampo = EdgeInsets.symmetric(horizontal: 16, vertical: 16);
}

/// Tema do app, montado conforme o modo escolhido (PulynColors.claro).
ThemeData construirTema() {
  return _construirTemaBase(PulynColors.claro);
}

/// Tema atual (conforme PulynColors.claro). Mantido para quem ainda usa `appTheme`.
ThemeData get appTheme => construirTema();

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

  final bordaCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(PulynMedidas.raioCampo),
    borderSide: BorderSide(color: PulynColors.darkBorder),
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
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: PulynColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: PulynColors.darkCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PulynMedidas.raioCartao),
        side: BorderSide(color: PulynColors.darkBorder, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PulynColors.darkSurface,
      contentPadding: PulynMedidas.paddingCampo,
      border: bordaCampo,
      enabledBorder: bordaCampo,
      disabledBorder: bordaCampo,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PulynMedidas.raioCampo),
        borderSide: BorderSide(color: PulynColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PulynMedidas.raioCampo),
        borderSide: BorderSide(color: PulynColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PulynMedidas.raioCampo),
        borderSide: BorderSide(color: PulynColors.danger, width: 1.5),
      ),
      labelStyle: TextStyle(color: PulynColors.textSecondary),
      floatingLabelStyle: TextStyle(color: PulynColors.primary),
      hintStyle: TextStyle(color: PulynColors.textMuted),
      helperStyle: TextStyle(color: PulynColors.textMuted, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PulynColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PulynColors.primary.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(PulynMedidas.alturaBotao),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulynMedidas.raioBotao)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PulynColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: PulynColors.primary.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(PulynMedidas.alturaBotao),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulynMedidas.raioBotao)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PulynColors.primary,
        minimumSize: const Size.fromHeight(PulynMedidas.alturaBotao),
        side: BorderSide(color: PulynColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PulynMedidas.raioBotao)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PulynColors.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textTheme: TextTheme(
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: PulynColors.textPrimary),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: PulynColors.textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PulynColors.textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PulynColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: PulynColors.textSecondary),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: PulynColors.textMuted),
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
