/// history_repository.dart
/// -----------------------------------------------------------------------
/// Hive-backed storage for saved calculations (HistoryEntry = InputModel
/// + OutputModel + timestamp). This is "the Hive adapter for InputModel +
/// OutputModel" — instead of @HiveType code-gen classes, it stores each
/// HistoryEntry as a Map via toJson()/fromJson(), same pattern as
/// SizingRatesRepository. No build_runner step needed.
///
/// SETUP STEPS (do these in order):
///
/// 1. pubspec.yaml already has hive + hive_flutter (added back in
///    sizing_rates_repository.dart's setup) — nothing new to add here.
///
/// 2. In main.dart, alongside the existing
///    SizingRatesRepository.instance.init() call, add:
///      await HistoryRepository.instance.init();
///
/// 3. Sara's save logic (Phase 5, Step 2) calls this after every
///    successful recalculation:
///      await HistoryRepository.instance.save(
///        HistoryEntry.now(input: input, output: output),
///      );
///
/// 4. The History screen reads entries via:
///      final entries = HistoryRepository.instance.getAll();
///    (already sorted newest-first — see getAll() below)
///
/// WHY NOT AUTO-SAVE INSIDE InputScreen DIRECTLY:
/// Keeping save() as an explicit call (rather than wiring it inside
/// CalculationEngine or _recalculate()) keeps this repository decoupled
/// from the UI layer — Sara's save/load logic decides WHEN to save
/// (e.g. on every recalculation, or only on a "Save" button, debounced,
/// etc.) without this file needing to know about that policy.
library;

import 'package:hive/hive.dart';
import '../models/history_entry_model.dart';

class HistoryRepository {
  HistoryRepository._internal();
  static final HistoryRepository instance = HistoryRepository._internal();

  static const String _boxName = 'history';

  late Box<Map> _box;

  /// Call once at app startup (after Hive.initFlutter()), alongside
  /// SizingRatesRepository.instance.init().
  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Saves one calculation. Uses entry.id as the Hive key, so calling
  /// save() again with the same id (e.g. re-saving an edited entry)
  /// overwrites rather than duplicating.
  Future<void> save(HistoryEntry entry) async {
    await _box.put(entry.id, entry.toJson());
  }

  /// All saved entries, newest first (by savedAt) — ready to feed
  /// straight into the History screen's card list.
  List<HistoryEntry> getAll() {
    final entries = _box.values
        .map((raw) => HistoryEntry.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
    entries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return entries;
  }

  /// Single entry by id — used by "tap to reload" (Rabia, Phase 5 Step 3)
  /// if the caller only has an id rather than the full HistoryEntry.
  HistoryEntry? getById(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return HistoryEntry.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Deletes one entry — used by the delete option on history cards
  /// (Sara, Phase 5 Step 4).
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Deletes everything — used by "Clear history" in Settings.
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Number of saved entries — handy for an empty-state check in the
  /// History screen without loading/parsing every entry.
  int get count => _box.length;
}