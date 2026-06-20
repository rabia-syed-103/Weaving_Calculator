/// app_theme.dart
/// -----------------------------------------------------------------------
/// Defines the 5 SadeedTex accent colors and builds a ThemeData for any
/// (accent, brightness) combination using Flutter's ColorScheme.fromSeed.
///
/// Why fromSeed: you only need ONE color per accent (the "seed"). Flutter
/// derives every other shade — including ones that work correctly in both
/// light and dark mode — automatically. This is what gives you "pick
/// green, and it looks right in both Light and Dark" without manually
/// defining two palettes per color.
library;

import 'package:flutter/material.dart';

enum AccentColor { green, teal, blue, purple, coral }

extension AccentColorLabel on AccentColor {
  String get label {
    switch (this) {
      case AccentColor.green:
        return 'Green';
      case AccentColor.teal:
        return 'Teal';
      case AccentColor.blue:
        return 'Blue';
      case AccentColor.purple:
        return 'Purple';
      case AccentColor.coral:
        return 'Coral';
    }
  }
}

class AppTheme {
  AppTheme._();

  /// One seed color per accent. These are the SadeedTex brand swatches —
  /// change the hex values here if the design team gives you exact ones.
  static const Map<AccentColor, Color> seedColors = {
    AccentColor.green: Color(0xFF3B6D11),
    AccentColor.teal: Color(0xFF0F6E56),
    AccentColor.blue: Color(0xFF185FA5),
    AccentColor.purple: Color(0xFF534AB7),
    AccentColor.coral: Color(0xFF993C1D),
  };

  static ThemeData build({
    required AccentColor accent,
    required Brightness brightness,
  }) {
    final seed = seedColors[accent]!;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),
    );
  }
}