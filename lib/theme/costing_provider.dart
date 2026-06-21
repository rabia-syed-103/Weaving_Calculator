/// costing_provider.dart
/// -----------------------------------------------------------------------
/// Holds the most recently calculated OutputModel AND the InputModel that
/// produced it, notifying listeners when either changes.
///
/// UPDATED to also track `lastInput` (previously this only held
/// `output`). The share feature needs both — ShareActionButton builds a
/// HistoryEntry(input, output) to export as Excel, and a HistoryEntry
/// needs the InputModel too, not just the OutputModel. Sara's existing
/// `update(output)` call sites need ONE small change — see USAGE below.
///
/// Pattern matches ThemeProvider exactly (same ChangeNotifier + Provider
/// approach already used elsewhere in this app).
///
/// USAGE:
///   - InputScreen calls
///       context.read<CostingProvider>().update(input, output)
///     at the end of _recalculate(), instead of setState on local fields.
///     (CHANGED — update() now takes input as well as output; if your
///     current call site only passes output, add the input argument.)
///   - Any screen that wants the live numbers (OutputsScreen,
///     ShareActionButton) calls context.watch<CostingProvider>().output
///     and/or .lastInput to read them.
///   - Both are null until the first successful calculation — screens
///     reading them should treat null the same way InputScreen currently
///     treats "not enough data yet" (i.e. show 0 / a placeholder state,
///     or disable the share button).
library;

import 'package:flutter/foundation.dart';
import '../models/input_model.dart';
import '../models/output_model.dart';

class CostingProvider extends ChangeNotifier {
  OutputModel? _output;
  InputModel? _lastInput;

  OutputModel? get output => _output;
  InputModel? get lastInput => _lastInput;

  /// Called whenever a new calculation completes successfully.
  void update(InputModel input, OutputModel output) {
    _lastInput = input;
    _output = output;
    notifyListeners();
  }

  /// Called when the form becomes invalid/incomplete (matches the old
  /// "show 0" behavior in InputScreen._recalculate when required fields
  /// are missing or no Sizing Rate match is found). Deliberately does
  /// NOT clear _lastInput — if the user has an old valid result on
  /// screen and briefly types something invalid, the share button
  /// should arguably still offer the last good snapshot rather than
  /// disabling itself instantly. (If you'd rather it disable
  /// immediately on any invalid state, clear _lastInput here too.)
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