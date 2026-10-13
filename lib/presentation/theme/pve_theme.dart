import 'package:flutter/material.dart';

abstract final class PveTheme {
  static const primaryBlue = Color(0xFF3448C8);
  static const accentOrange = Color(0xFFF79009);
  static const background = Color(0xFFF5F7FB);
  static const textColor = Color(0xFF172239);
  static const secondaryText = Color(0xFF6F7C92);
  static const fontFamily = 'Noto Sans SC';

  static TextStyle text(
    double size,
    double lineHeight, {
    FontWeight weight = FontWeight.w400,
    Color color = textColor,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: color,
  );

  static ThemeData light() {
    final colors =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryBlue,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE9EDFF),
          onPrimaryContainer: primaryBlue,
          secondary: const Color(0xFF169573),
          surface: Colors.white,
          onSurface: textColor,
          onSurfaceVariant: secondaryText,
          surfaceContainerLowest: const Color(0xFFF8FAFD),
          surfaceContainerLow: const Color(0xFFF1F4FA),
          surfaceContainer: const Color(0xFFEDF0F6),
          surfaceContainerHigh: const Color(0xFFE7ECF5),
          surfaceContainerHighest: const Color(0xFFE0E6F0),
          outline: const Color(0xFFADB8CC),
          outlineVariant: const Color(0xFFE5E9F1),
          error: const Color(0xFFB42318),
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE2E7F0)),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      textTheme: TextTheme(
        displayLarge: text(36, 46, weight: FontWeight.w700),
        displayMedium: text(32, 42, weight: FontWeight.w700),
        displaySmall: text(28, 38, weight: FontWeight.w700),
        headlineLarge: text(28, 40, weight: FontWeight.w700),
        headlineMedium: text(25, 36, weight: FontWeight.w700),
        headlineSmall: text(25, 36, weight: FontWeight.w700),
        titleLarge: text(21, 30, weight: FontWeight.w600),
        titleMedium: text(14, 20, weight: FontWeight.w600),
        titleSmall: text(13, 19, weight: FontWeight.w600),
        bodyLarge: text(13, 19),
        bodyMedium: text(12, 17),
        bodySmall: text(11, 16),
        labelLarge: text(14, 20, weight: FontWeight.w600),
        labelMedium: text(12, 17, weight: FontWeight.w500),
        labelSmall: text(11, 16, weight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text(25, 36, weight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E9F1)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEDF0F6),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13.5,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        hintStyle: text(13, 19, color: secondaryText),
        errorStyle: text(11, 16, color: colors.error),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0xFFE5E9F1)),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        hintStyle: WidgetStatePropertyAll(text(13, 19, color: secondaryText)),
        textStyle: WidgetStatePropertyAll(text(13, 19)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: text(14, 20, weight: FontWeight.w600),
          shape: shape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF56647D),
          side: const BorderSide(color: Color(0xFFDCE2EE)),
          textStyle: text(13, 19, weight: FontWeight.w500),
          shape: shape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 46),
          foregroundColor: const Color(0xFF64718A),
          textStyle: text(13, 19, weight: FontWeight.w500),
          shape: shape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
