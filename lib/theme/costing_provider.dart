/// costing_provider.dart
/// -----------------------------------------------------------------------
/// Holds the most recently calculated OutputModel AND the InputModel that
/// produced it, notifying listeners when either changes.
///
/// Also handles "tap to reload" (Step 17): when the History screen taps
/// a card, it calls requestReload(entry.input). InputScreen watches
/// this provider and calls consumeReload() to fill its controllers, then
/// clears the pending state so it doesn't re-trigger on rebuilds.
library;

import 'package:flutter/foundation.dart';
import '../models/input_model.dart';
import '../models/output_model.dart';

class CostingProvider extends ChangeNotifier {
  OutputModel? _output;
  InputModel? _lastInput;
  InputModel? _pendingReload;

  OutputModel? get output => _output;
  InputModel? get lastInput => _lastInput;

  /// Non-null when History has requested a reload into InputScreen.
  /// InputScreen should call consumeReload() as soon as it reads this.
  InputModel? get pendingReload => _pendingReload;

  /// Called whenever a new calculation completes successfully.
  void update(InputModel input, OutputModel output) {
    _lastInput = input;
    _output = output;
    notifyListeners();
  }

  /// Called when the form becomes invalid/incomplete.
  void clear() {
    if (_output == null) return;
    _output = null;
    notifyListeners();
  }

  /// Called by HistoryScreen when user taps a history card.
  /// InputScreen watches this and fills its controllers when non-null.
  void requestReload(InputModel input) {
    _pendingReload = input;
    notifyListeners();
  }

  /// Called by InputScreen immediately after it reads pendingReload and
  /// fills its controllers — clears the pending state so it doesn't
  /// re-trigger on the next rebuild.
  void consumeReload() {
    if (_pendingReload == null) return;
    _pendingReload = null;
    // No notifyListeners() here — InputScreen already has what it needs,
    // and calling notify would cause an unnecessary extra rebuild.
  }
}
