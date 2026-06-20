/// costing_provider.dart
/// -----------------------------------------------------------------------
/// Holds the most recently calculated OutputModel and notifies listeners
/// when it changes. This is what makes the headline card (Grey Fabric
/// Rate + Loom In Flow) show the SAME live numbers on both the Costing
/// screen and the Outputs screen — previously those values were trapped
/// inside InputScreen's private State, so OutputsPlaceholderScreen could
/// only ever show hardcoded zeros.
///
/// Pattern matches ThemeProvider exactly (same ChangeNotifier + Provider
/// approach already used elsewhere in this app) so there's only one way
/// shared state is handled across the codebase, not two.
///
/// USAGE:
///   - InputScreen calls context.read<CostingProvider>().update(output)
///     at the end of _recalculate(), instead of setState on local fields.
///   - Any screen that wants the live numbers (OutputsPlaceholderScreen,
///     and eventually Rabia's real tabbed Outputs screen) calls
///     context.watch<CostingProvider>().output to read them.
///   - `output` is null until the first successful calculation — screens
///     reading it should treat null the same way InputScreen currently
///     treats "not enough data yet" (i.e. show 0 / a placeholder state).
library;

import 'package:flutter/foundation.dart';
import '../models/output_model.dart';

class CostingProvider extends ChangeNotifier {
  OutputModel? _output;

  OutputModel? get output => _output;

  /// Called whenever a new calculation completes successfully.
  void update(OutputModel output) {
    _output = output;
    notifyListeners();
  }

  /// Called when the form becomes invalid/incomplete (matches the old
  /// "show 0" behavior in InputScreen._recalculate when required fields
  /// are missing or no Sizing Rate match is found).
  void clear() {
    if (_output == null) return; // avoid redundant rebuilds
    _output = null;
    notifyListeners();
  }
}

/// ---------------------------------------------------------------------
/// USAGE — in main.dart, alongside the existing ThemeProvider:
///
/// runApp(
///   MultiProvider(
///     providers: [
///       ChangeNotifierProvider(create: (_) => ThemeProvider()),
///       ChangeNotifierProvider(create: (_) => CostingProvider()),
///     ],
///     child: const SadeedTexApp(),
///   ),
/// );
/// ---------------------------------------------------------------------