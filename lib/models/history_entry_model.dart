/// history_entry_model.dart
/// -----------------------------------------------------------------------
/// One saved calculation — bundles the InputModel that produced it, the
/// resulting OutputModel, and a timestamp. This is the record Hive
/// actually stores; Sara's save/load logic (Phase 5, Step 2) works with
/// HistoryEntry objects, not raw InputModel/OutputModel separately.
///
/// `id` is a simple millisecond-timestamp string — unique enough for a
/// single-device local history, and doubles as a natural sort key
/// (newest first) without needing a separate sequence counter.
library;

import 'input_model.dart';
import 'output_model.dart';

class HistoryEntry {
  final String id;
  final DateTime savedAt;
  final InputModel input;
  final OutputModel output;

  HistoryEntry({
    required this.id,
    required this.savedAt,
    required this.input,
    required this.output,
  });

  /// Convenience constructor for creating a fresh entry at save time —
  /// generates id/savedAt from "now" so callers (Sara's save logic)
  /// don't have to.
  factory HistoryEntry.now({
    required InputModel input,
    required OutputModel output,
  }) {
    final now = DateTime.now();
    return HistoryEntry(
      id: now.millisecondsSinceEpoch.toString(),
      savedAt: now,
      input: input,
      output: output,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'input': input.toJson(),
    'output': output.toJson(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      input: InputModel.fromJson(Map<String, dynamic>.from(json['input'] as Map)),
      output: OutputModel.fromJson(Map<String, dynamic>.from(json['output'] as Map)),
    );
  }

  @override
  String toString() => 'HistoryEntry(id: $id, savedAt: $savedAt)';
}