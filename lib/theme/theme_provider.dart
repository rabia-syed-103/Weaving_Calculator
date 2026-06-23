/// theme_provider.dart
/// -----------------------------------------------------------------------
/// Holds the user's current theme choice (accent color + light/dark mode)
/// and notifies the app to rebuild when either changes. Wrap MaterialApp
/// with this (see main.dart usage at the bottom of this file).
///
/// PERSISTENCE (now implemented via Hive):
/// Previously in-memory only — every restart reset to AccentColor.green +
/// ThemeMode.system, which is exactly the bug reported ("picked Light +
/// Green, restarted, got Dark + Green" — accent survived only because
/// green happens to be the default, but the mode never persisted at
/// all). Fixed by reading/writing a small Hive box:
///   - Box name: 'theme_box'
///   - Keys: 'accent' (stores AccentColor.name, a String) and
///     'themeMode' (stores ThemeMode.name, a String)
///
/// Storing the enum's .name (e.g. "green", "dark") instead of its index
/// is deliberate — if AccentColor or ThemeMode ever gets a value
/// inserted in the middle, index-based storage would silently load the
/// WRONG color/mode for existing users. Name-based storage only breaks
/// if a value is renamed, which is rare and easy to spot.
///
/// IMPORTANT — this box must be opened before ThemeProvider is
/// constructed. See the init() factory below and the updated main.dart
/// usage at the bottom of this file: main() now awaits
/// ThemeProvider.load() instead of calling ThemeProvider() directly.
library;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'theme_box';
  static const String _accentKey = 'accent';
  static const String _themeModeKey = 'themeMode';

  late Box _box;

  AccentColor _accent;
  ThemeMode _themeMode;

  ThemeProvider._(this._box, this._accent, this._themeMode);

  /// Opens (or reuses) the Hive box and constructs a ThemeProvider
  /// already loaded with whatever was saved last time — or the
  /// defaults (green / system) on first ever launch.
  static Future<ThemeProvider> load() async {
    final box = await Hive.openBox(_boxName);

    final savedAccentName = box.get(_accentKey) as String?;
    final accent = AccentColor.values.firstWhere(
          (a) => a.name == savedAccentName,
      orElse: () => AccentColor.green,
    );

    final savedModeName = box.get(_themeModeKey) as String?;
    final mode = ThemeMode.values.firstWhere(
          (m) => m.name == savedModeName,
      orElse: () => ThemeMode.system,
    );

    return ThemeProvider._(box, accent, mode);
  }

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
    _box.put(_accentKey, accent.name);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _box.put(_themeModeKey, mode.name);
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
///   await HistoryRepository.instance.init();
///   final themeProvider = await ThemeProvider.load(); // CHANGED
///   runApp(
///     MultiProvider(
///       providers: [
///         ChangeNotifierProvider.value(value: themeProvider), // CHANGED
///         ChangeNotifierProvider(create: (_) => CostingProvider()),
///       ],
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
///       home: const MainNavShell(),
///     );
///   }
/// }
/// ---------------------------------------------------------------------