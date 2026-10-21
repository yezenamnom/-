import 'package:flutter/material.dart';

/// Calm, low-contrast surfaces with one accent colour. Brand colours are
/// placeholders until the final identity exists.
class AppTheme {
  static const _seed = Color(0xFF2E7D74);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surfaceContainer,
        height: 64,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Distinct background for the tab switcher (and private mode).
  static Color tabsBackground(ColorScheme s) => s.surfaceContainerHigh;
  static Color privateBackground(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF1D1730) : const Color(0xFF2A2140);
}
