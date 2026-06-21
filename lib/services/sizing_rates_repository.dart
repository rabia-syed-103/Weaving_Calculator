/// SizingRatesRepository
/// -----------------------------------------------------------------------
/// Owns the editable Sizing Rates lookup table — replaces the "Sizing
/// Rates" sheet + VLOOKUP from the Excel file (B17:
/// =VLOOKUP(C5,'Sizing Rates'!A1:F207,5,FALSE)).
///
/// On first launch, the table is seeded from assets/data/sizing_rates.json
/// (206 rows, copied directly from the Excel workbook) into Hive, so the
/// app works immediately. After that, Hive is the source of truth — the
/// user can add, edit, or delete rates from a Settings screen, and those
/// changes persist and are used by every future calculation.
///
/// CLOSEST-MATCH FALLBACK (lookup()):
/// If there's no exact Count+Ply+Blend match (e.g. a customer specs a
/// 37 count but the table only has 36 and 38 for that Ply+Blend), lookup
/// falls back to the row with the NEAREST Count, holding Ply and Blend
/// FIXED — i.e. Ply and Blend must still match exactly; only Count is
/// allowed to differ. This is silent (no UI flag/message) per direct
/// instruction — the returned SizingRateModel's own `count` field will
/// simply reflect whichever row was actually used, which is enough for
/// anyone inspecting the result later (e.g. in an exported Excel sheet)
/// without needing a separate "was this approximate" indicator in the UI.
///
/// If two rows are EQUALLY close (e.g. asking for 37 when the table has
/// 36 and 38), the lower count wins — arbitrary but deterministic, so
/// repeated lookups for the same input always return the same row.
///
/// SETUP STEPS (do these in order):
///
/// 1. Add Hive + hive_flutter to pubspec.yaml:
///      dependencies:
///        hive: ^2.2.3
///        hive_flutter: ^1.1.0
///      dev_dependencies:
///        hive_generator: ^2.0.1
///        build_runner: ^2.4.6
///
/// 2. Copy sizing_rates.json (206 rows, already extracted from the Excel
///    file) into your project at:
///      assets/data/sizing_rates.json
///    Then register it in pubspec.yaml:
///      flutter:
///        assets:
///          - assets/data/sizing_rates.json
///
/// 3. In main(), before runApp(), call:
///      await Hive.initFlutter();
///      await SizingRatesRepository.instance.init();
///
/// 4. Anywhere you need a rate (i.e. right before calling
///    CalculationEngine.calculate()), do:
///      final rate = SizingRatesRepository.instance.lookup(
///        count: input.warpCount,
///        ply: input.ply,
///        blend: input.warpBlend,
///      );
///      if (rate == null) {
///        // No row exists for this Ply+Blend at ANY count — show the
///        // user a message and let them either pick a different
///        // blend/ply or add a new rate manually.
///      } else {
///        final output = CalculationEngine.calculate(
///          input: input,
///          sizingCostPerKg: rate.perKg,
///          ...
///        );
///      }
library;

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import '../models/sizing_rate_model.dart';

class SizingRatesRepository {
  SizingRatesRepository._internal();
  static final SizingRatesRepository instance = SizingRatesRepository._internal();

  static const String _boxName = 'sizing_rates';
  static const String _seedAssetPath = 'assets/data/sizing_rates.json';
  static const String _seededFlagKey = '_seeded';

  late Box<Map> _box;

  /// Call once at app startup (after Hive.initFlutter()).
  /// Opens the Hive box and seeds it from the bundled JSON the first
  /// time the app ever runs. Safe to call on every launch — seeding
  /// only happens once.
  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);

    final alreadySeeded = _box.get(_seededFlagKey) != null;
    if (!alreadySeeded) {
      await _seedFromAsset();
      await _box.put(_seededFlagKey, {'done': true});
    }
  }

  Future<void> _seedFromAsset() async {
    final raw = await rootBundle.loadString(_seedAssetPath);
    final List<dynamic> rows = jsonDecode(raw) as List<dynamic>;
    for (final row in rows) {
      final rate = SizingRateModel.fromJson(row as Map<String, dynamic>);
      await _box.put(rate.key, rate.toJson());
    }
  }

  /// Look up a rate by Count + Ply + Blend — mirrors the Excel VLOOKUP
  /// on the concatenated key (e.g. "60/2 Ctn"). Tries an exact match
  /// first; if none exists, falls back to the row with the nearest
  /// Count for the SAME Ply + Blend (see class doc comment above).
  /// Returns null only if there is no row at all for that Ply + Blend,
  /// at any count — the Excel sheet would show #N/A in that case too.
  SizingRateModel? lookup({
    required double count,
    required double ply,
    required String blend,
  }) {
    final key = SizingRateModel.buildKey(count: count, ply: ply, blend: blend);
    final exact = lookupByKey(key);
    if (exact != null) return exact;

    return _findClosestByCount(count: count, ply: ply, blend: blend);
  }

  /// Look up directly by the pre-built key string, if you already have it.
  /// This is an EXACT lookup only — no closest-match fallback. Use
  /// lookup() instead unless you specifically need exact-or-nothing.
  SizingRateModel? lookupByKey(String key) {
    final raw = _box.get(key);
    if (raw == null) return null;
    return SizingRateModel.fromJson(Map<String, dynamic>.from(raw));
  }

  /// Scans all rows for the given Ply + Blend and returns the one whose
  /// Count is numerically closest to [count]. Ties broken by lower count
  /// (deterministic — see class doc comment). Returns null if there are
  /// no rows at all for that Ply + Blend.
  SizingRateModel? _findClosestByCount({
    required double count,
    required double ply,
    required String blend,
  }) {
    SizingRateModel? best;
    double bestDistance = double.infinity;

    for (final candidate in getAll()) {
      if (candidate.ply != ply || candidate.blend != blend) continue;

      final distance = (candidate.count - count).abs();
      final isCloser = distance < bestDistance;
      final isTieButLower = distance == bestDistance &&
          best != null &&
          candidate.count < best.count;

      if (isCloser || isTieButLower) {
        best = candidate;
        bestDistance = distance;
      }
    }

    return best;
  }

  /// All rates currently in the table — for a "Manage Sizing Rates"
  /// settings screen (list/search/edit UI), and used internally by the
  /// closest-match fallback above.
  List<SizingRateModel> getAll() {
    return _box.keys
        .where((k) => k != _seededFlagKey)
        .map((k) => SizingRateModel.fromJson(Map<String, dynamic>.from(_box.get(k)!)))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Add a brand-new rate, or overwrite an existing one with the same
  /// Count/Ply/Blend. This is how the user "catches up" rates that
  /// change in future — edit screen calls this on save.
  Future<void> upsert(SizingRateModel rate) async {
    await _box.put(rate.key, rate.toJson());
  }

  /// Remove a rate entirely.
  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  /// Restore the table to the original 206 rates from the Excel file,
  /// discarding any edits. Useful as a "Reset to defaults" button.
  Future<void> resetToDefaults() async {
    await _box.clear();
    await _seedFromAsset();
    await _box.put(_seededFlagKey, {'done': true});
  }
}