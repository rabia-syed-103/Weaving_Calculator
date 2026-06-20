/// theme_provider.dart
/// -----------------------------------------------------------------------
/// Holds the user's current theme choice (accent color + light/dark mode)
/// and notifies the app to rebuild when either changes. Wrap MaterialApp
/// with this (see main.dart usage at the bottom of this file).
///
/// Persistence: currently in-memory only (resets on app restart). To
/// persist across restarts later, save accent/mode to Hive in setAccent/
/// setThemeMode and read them back in a constructor — flagged here so
/// it isn't forgotten, but not required for v1.
library;

import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AccentColor _accent = AccentColor.green;
  ThemeMode _themeMode = ThemeMode.system;

  AccentColor get accent => _accent;
  ThemeMode get themeMode => _themeMode;

  /// True if the *resolved* brightness is dark — i.e. ThemeMode.dark,
  /// or ThemeMode.system while the OS is in dark mode. Widgets that need
  /// to know "am I dark right now" (not just "what mode is selected")
  /// should use Theme.of(context).brightness instead of this directly;
  /// this getter is mainly for the Settings drawer to highlight the
  /// correct Light/Dark button when "System" maps to a known case.
  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  void setAccent(AccentColor accent) {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleLightDark() {
    setThemeMode(isDark(_lastContext!) ? ThemeMode.light : ThemeMode.dark);
  }

  // Only used by toggleLightDark() as a fallback if no context is passed
  // explicitly — prefer calling setThemeMode(...) directly from widgets
  // where you already have a BuildContext.
  BuildContext? _lastContext;
  void registerContext(BuildContext context) => _lastContext = context;
}

/// ---------------------------------------------------------------------
/// USAGE — in main.dart:
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Hive.initFlutter();
///   await SizingRatesRepository.instance.init();
///   runApp(
///     ChangeNotifierProvider(
///       create: (_) => ThemeProvider(),
///       child: const SadeedTexApp(),
///     ),
///   );
/// }
///
/// class SadeedTexApp extends StatelessWidget {
///   const SadeedTexApp({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     final themeProvider = context.watch<ThemeProvider>();
///     return MaterialApp(
///       title: 'SadeedTex',
///       theme: AppTheme.build(
///         accent: themeProvider.accent,
///         brightness: Brightness.light,
///       ),
///       darkTheme: AppTheme.build(
///         accent: themeProvider.accent,
///         brightness: Brightness.dark,
///       ),
///       themeMode: themeProvider.themeMode,
///       home: const InputScreen(),
///     );
///   }
/// }
/// ---------------------------------------------------------------------