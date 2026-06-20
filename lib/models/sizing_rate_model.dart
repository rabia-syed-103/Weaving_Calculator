/// SizingRateModel
/// -----------------------------------------------------------------------
/// One row of the Sizing Rates lookup table (the "Sizing Rates" sheet in
/// Costing_InFlow_PerPick.xlsm). Used by SizingRatesRepository.
///
/// In the Excel file, the lookup key is built as:
///   ="{Count}/{Ply} {Blend}"   e.g.  "60/2 Ctn"
/// and matched against column A ("Yarn Count") via VLOOKUP, returning
/// column E ("Per Kg"). `key` here is exactly that string, pre-built,
/// so lookups are a simple map access instead of string concatenation
/// at query time.
library;

class SizingRateModel {
  final String key;       // e.g. "60/2 Ctn" — Count/Ply Blend
  final double count;     // Yarn count (Ne), e.g. 60
  final double ply;       // e.g. 1, 2
  final String blend;     // e.g. "Ctn", "Pc", "Pv", "Pp", "Cvc", "Viscose"
  final double perKg;     // Sizing cost per Kg — this is what
  // calculation_engine.dart needs as sizingCostPerKg
  final double perLbs;    // Sizing cost per Lbs — kept for reference/display

  const SizingRateModel({
    required this.key,
    required this.count,
    required this.ply,
    required this.blend,
    required this.perKg,
    required this.perLbs,
  });

  /// Builds the lookup key the same way the Excel sheet does:
  /// =c_Warp_Count&"/"&Ply&" "&Blend
  static String buildKey({
    required double count,
    required double ply,
    required String blend,
  }) {
    final countStr = count == count.roundToDouble()
        ? count.toInt().toString()
        : count.toString();
    final plyStr = ply == ply.roundToDouble()
        ? ply.toInt().toString()
        : ply.toString();
    return '$countStr/$plyStr $blend';
  }

  SizingRateModel copyWith({
    String? key,
    double? count,
    double? ply,
    String? blend,
    double? perKg,
    double? perLbs,
  }) {
    return SizingRateModel(
      key: key ?? this.key,
      count: count ?? this.count,
      ply: ply ?? this.ply,
      blend: blend ?? this.blend,
      perKg: perKg ?? this.perKg,
      perLbs: perLbs ?? this.perLbs,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'count': count,
    'ply': ply,
    'blend': blend,
    'perKg': perKg,
    'perLbs': perLbs,
  };

  factory SizingRateModel.fromJson(Map<String, dynamic> json) {
    double _d(dynamic v) => (v as num).toDouble();
    return SizingRateModel(
      key: json['key'] as String,
      count: _d(json['count']),
      ply: _d(json['ply']),
      blend: json['blend'] as String,
      perKg: _d(json['perKg']),
      perLbs: _d(json['perLbs']),
    );
  }

  @override
  String toString() => 'SizingRateModel(${toJson()})';
}