/// InputModel
/// -----------------------------------------------------------------------
/// Holds every input field from the Fabric Costing Sheet (Section A) plus
/// the optional Additional Yarn block (Section 2.1 in the project manual).
///
/// Numeric fields use `double` (not `int`) because costing values like
/// counts, percentages, and rates are rarely whole numbers.
/// Additional Yarn fields are nullable — null means "not used", and the
/// calculation_engine should treat null the same way the Excel sheet
/// treats a blank cell (skip / treat as 0).
library;

class InputModel {
  // ---------------------------------------------------------------------
  // Section A — Core Fabric Specification (30 fields)
  // ---------------------------------------------------------------------
  final String warpBlend;
  final double ply;
  final double warpCount;        // Warp Count (Ne)
  final double weftCount;        // Weft Count (Ne)
  final double endsPerInch;
  final double picksPerInch;
  final double width;
  final String weave;
  final String selvedge;
  final String writing;
  final double warpShrinkagePct;
  final double weftShrinkagePct;
  final double warpWastagePct;
  final double weftWastagePct;
  final double warpYarnRate;
  final double weftYarnRate;
  final double sizingCostPerKg;
  final double commissionPct;
  final double offGradePct;
  final double offGradeRecovery;
  final double loomRpm;
  final double loomEfficiencyPct;
  final double pickInsertion;
  final double widthsPerLoom;    // No. of Widths per Loom
  final double numberOfLooms;    // No. of Looms
  final double totalOrder;
  final double inputInflow;
  final double targetPrice;
  final double perPickRate;
  final double packingCost;
  final double freightCost;

  // ---------------------------------------------------------------------
  // Section 2.1 — Additional Yarn (optional, nullable)
  // ---------------------------------------------------------------------
  final double? additionalWarpCount;
  final double? additionalWeftCount;
  final double? additionalEndsPerInch;
  final double? additionalPicksPerInch;
  final double? additionalWarpShrinkagePct;
  final double? additionalWeftShrinkagePct;
  final double? additionalWarpWastagePct;
  final double? additionalWeftWastagePct;
  final double? additionalWarpYarnRate;
  final double? additionalWeftYarnRate;

  const InputModel({
    // Section A — required
    required this.warpBlend,
    required this.ply,
    required this.warpCount,
    required this.weftCount,
    required this.endsPerInch,
    required this.picksPerInch,
    required this.width,
    required this.weave,
    required this.selvedge,
    required this.writing,
    required this.warpShrinkagePct,
    required this.weftShrinkagePct,
    required this.warpWastagePct,
    required this.weftWastagePct,
    required this.warpYarnRate,
    required this.weftYarnRate,
    required this.sizingCostPerKg,
    required this.commissionPct,
    required this.offGradePct,
    required this.offGradeRecovery,
    required this.loomRpm,
    required this.loomEfficiencyPct,
    required this.pickInsertion,
    required this.widthsPerLoom,
    required this.numberOfLooms,
    required this.totalOrder,
    required this.inputInflow,
    required this.targetPrice,
    required this.perPickRate,
    required this.packingCost,
    required this.freightCost,
    // Section 2.1 — optional
    this.additionalWarpCount,
    this.additionalWeftCount,
    this.additionalEndsPerInch,
    this.additionalPicksPerInch,
    this.additionalWarpShrinkagePct,
    this.additionalWeftShrinkagePct,
    this.additionalWarpWastagePct,
    this.additionalWeftWastagePct,
    this.additionalWarpYarnRate,
    this.additionalWeftYarnRate,
  });

  /// True if the user filled in the Additional Yarn block at all.
  /// Use this in calculation_engine.dart to decide whether to run the
  /// "2nd warp/weft" formulas or skip them.
  bool get hasAdditionalYarn =>
      additionalWarpCount != null ||
          additionalWeftCount != null ||
          additionalEndsPerInch != null ||
          additionalPicksPerInch != null;

  // ---------------------------------------------------------------------
  // copyWith — handy when editing one field at a time on the input screen,
  // or when "tap to reload" pulls a history entry back into the form.
  // ---------------------------------------------------------------------
  InputModel copyWith({
    String? warpBlend,
    double? ply,
    double? warpCount,
    double? weftCount,
    double? endsPerInch,
    double? picksPerInch,
    double? width,
    String? weave,
    String? selvedge,
    String? writing,
    double? warpShrinkagePct,
    double? weftShrinkagePct,
    double? warpWastagePct,
    double? weftWastagePct,
    double? warpYarnRate,
    double? weftYarnRate,
    double? sizingCostPerKg,
    double? commissionPct,
    double? offGradePct,
    double? offGradeRecovery,
    double? loomRpm,
    double? loomEfficiencyPct,
    double? pickInsertion,
    double? widthsPerLoom,
    double? numberOfLooms,
    double? totalOrder,
    double? inputInflow,
    double? targetPrice,
    double? perPickRate,
    double? packingCost,
    double? freightCost,
    double? additionalWarpCount,
    double? additionalWeftCount,
    double? additionalEndsPerInch,
    double? additionalPicksPerInch,
    double? additionalWarpShrinkagePct,
    double? additionalWeftShrinkagePct,
    double? additionalWarpWastagePct,
    double? additionalWeftWastagePct,
    double? additionalWarpYarnRate,
    double? additionalWeftYarnRate,
  }) {
    return InputModel(
      warpBlend: warpBlend ?? this.warpBlend,
      ply: ply ?? this.ply,
      warpCount: warpCount ?? this.warpCount,
      weftCount: weftCount ?? this.weftCount,
      endsPerInch: endsPerInch ?? this.endsPerInch,
      picksPerInch: picksPerInch ?? this.picksPerInch,
      width: width ?? this.width,
      weave: weave ?? this.weave,
      selvedge: selvedge ?? this.selvedge,
      writing: writing ?? this.writing,
      warpShrinkagePct: warpShrinkagePct ?? this.warpShrinkagePct,
      weftShrinkagePct: weftShrinkagePct ?? this.weftShrinkagePct,
      warpWastagePct: warpWastagePct ?? this.warpWastagePct,
      weftWastagePct: weftWastagePct ?? this.weftWastagePct,
      warpYarnRate: warpYarnRate ?? this.warpYarnRate,
      weftYarnRate: weftYarnRate ?? this.weftYarnRate,
      sizingCostPerKg: sizingCostPerKg ?? this.sizingCostPerKg,
      commissionPct: commissionPct ?? this.commissionPct,
      offGradePct: offGradePct ?? this.offGradePct,
      offGradeRecovery: offGradeRecovery ?? this.offGradeRecovery,
      loomRpm: loomRpm ?? this.loomRpm,
      loomEfficiencyPct: loomEfficiencyPct ?? this.loomEfficiencyPct,
      pickInsertion: pickInsertion ?? this.pickInsertion,
      widthsPerLoom: widthsPerLoom ?? this.widthsPerLoom,
      numberOfLooms: numberOfLooms ?? this.numberOfLooms,
      totalOrder: totalOrder ?? this.totalOrder,
      inputInflow: inputInflow ?? this.inputInflow,
      targetPrice: targetPrice ?? this.targetPrice,
      perPickRate: perPickRate ?? this.perPickRate,
      packingCost: packingCost ?? this.packingCost,
      freightCost: freightCost ?? this.freightCost,
      additionalWarpCount: additionalWarpCount ?? this.additionalWarpCount,
      additionalWeftCount: additionalWeftCount ?? this.additionalWeftCount,
      additionalEndsPerInch:
      additionalEndsPerInch ?? this.additionalEndsPerInch,
      additionalPicksPerInch:
      additionalPicksPerInch ?? this.additionalPicksPerInch,
      additionalWarpShrinkagePct:
      additionalWarpShrinkagePct ?? this.additionalWarpShrinkagePct,
      additionalWeftShrinkagePct:
      additionalWeftShrinkagePct ?? this.additionalWeftShrinkagePct,
      additionalWarpWastagePct:
      additionalWarpWastagePct ?? this.additionalWarpWastagePct,
      additionalWeftWastagePct:
      additionalWeftWastagePct ?? this.additionalWeftWastagePct,
      additionalWarpYarnRate:
      additionalWarpYarnRate ?? this.additionalWarpYarnRate,
      additionalWeftYarnRate:
      additionalWeftYarnRate ?? this.additionalWeftYarnRate,
    );
  }

  // ---------------------------------------------------------------------
  // JSON serialization — needed for Hive (Phase 5) and for voice input
  // debugging (Phase 6), so it's included now instead of bolted on later.
  // ---------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'warpBlend': warpBlend,
      'ply': ply,
      'warpCount': warpCount,
      'weftCount': weftCount,
      'endsPerInch': endsPerInch,
      'picksPerInch': picksPerInch,
      'width': width,
      'weave': weave,
      'selvedge': selvedge,
      'writing': writing,
      'warpShrinkagePct': warpShrinkagePct,
      'weftShrinkagePct': weftShrinkagePct,
      'warpWastagePct': warpWastagePct,
      'weftWastagePct': weftWastagePct,
      'warpYarnRate': warpYarnRate,
      'weftYarnRate': weftYarnRate,
      'sizingCostPerKg': sizingCostPerKg,
      'commissionPct': commissionPct,
      'offGradePct': offGradePct,
      'offGradeRecovery': offGradeRecovery,
      'loomRpm': loomRpm,
      'loomEfficiencyPct': loomEfficiencyPct,
      'pickInsertion': pickInsertion,
      'widthsPerLoom': widthsPerLoom,
      'numberOfLooms': numberOfLooms,
      'totalOrder': totalOrder,
      'inputInflow': inputInflow,
      'targetPrice': targetPrice,
      'perPickRate': perPickRate,
      'packingCost': packingCost,
      'freightCost': freightCost,
      'additionalWarpCount': additionalWarpCount,
      'additionalWeftCount': additionalWeftCount,
      'additionalEndsPerInch': additionalEndsPerInch,
      'additionalPicksPerInch': additionalPicksPerInch,
      'additionalWarpShrinkagePct': additionalWarpShrinkagePct,
      'additionalWeftShrinkagePct': additionalWeftShrinkagePct,
      'additionalWarpWastagePct': additionalWarpWastagePct,
      'additionalWeftWastagePct': additionalWeftWastagePct,
      'additionalWarpYarnRate': additionalWarpYarnRate,
      'additionalWeftYarnRate': additionalWeftYarnRate,
    };
  }

  factory InputModel.fromJson(Map<String, dynamic> json) {
    // (json['field'] as num).toDouble() handles both int and double
    // coming back from JSON/Hive — JSON doesn't distinguish them, so
    // this avoids "type 'int' is not a subtype of type 'double'" crashes.
    double _d(dynamic v) => (v as num).toDouble();
    double? _dOrNull(dynamic v) => v == null ? null : (v as num).toDouble();

    return InputModel(
      warpBlend: json['warpBlend'] as String,
      ply: _d(json['ply']),
      warpCount: _d(json['warpCount']),
      weftCount: _d(json['weftCount']),
      endsPerInch: _d(json['endsPerInch']),
      picksPerInch: _d(json['picksPerInch']),
      width: _d(json['width']),
      weave: json['weave'] as String,
      selvedge: json['selvedge'] as String,
      writing: json['writing'] as String,
      warpShrinkagePct: _d(json['warpShrinkagePct']),
      weftShrinkagePct: _d(json['weftShrinkagePct']),
      warpWastagePct: _d(json['warpWastagePct']),
      weftWastagePct: _d(json['weftWastagePct']),
      warpYarnRate: _d(json['warpYarnRate']),
      weftYarnRate: _d(json['weftYarnRate']),
      sizingCostPerKg: _d(json['sizingCostPerKg']),
      commissionPct: _d(json['commissionPct']),
      offGradePct: _d(json['offGradePct']),
      offGradeRecovery: _d(json['offGradeRecovery']),
      loomRpm: _d(json['loomRpm']),
      loomEfficiencyPct: _d(json['loomEfficiencyPct']),
      pickInsertion: _d(json['pickInsertion']),
      widthsPerLoom: _d(json['widthsPerLoom']),
      numberOfLooms: _d(json['numberOfLooms']),
      totalOrder: _d(json['totalOrder']),
      inputInflow: _d(json['inputInflow']),
      targetPrice: _d(json['targetPrice']),
      perPickRate: _d(json['perPickRate']),
      packingCost: _d(json['packingCost']),
      freightCost: _d(json['freightCost']),
      additionalWarpCount: _dOrNull(json['additionalWarpCount']),
      additionalWeftCount: _dOrNull(json['additionalWeftCount']),
      additionalEndsPerInch: _dOrNull(json['additionalEndsPerInch']),
      additionalPicksPerInch: _dOrNull(json['additionalPicksPerInch']),
      additionalWarpShrinkagePct:
      _dOrNull(json['additionalWarpShrinkagePct']),
      additionalWeftShrinkagePct:
      _dOrNull(json['additionalWeftShrinkagePct']),
      additionalWarpWastagePct: _dOrNull(json['additionalWarpWastagePct']),
      additionalWeftWastagePct: _dOrNull(json['additionalWeftWastagePct']),
      additionalWarpYarnRate: _dOrNull(json['additionalWarpYarnRate']),
      additionalWeftYarnRate: _dOrNull(json['additionalWeftYarnRate']),
    );
  }

  @override
  String toString() => 'InputModel(${toJson()})';
}

// ---------------------------------------------------------------------
// Example / sanity check — delete this once you've confirmed it compiles.
// Run with: dart run lib/models/input_model.dart
// ---------------------------------------------------------------------
void main() {
  const example = InputModel(
    warpBlend: '100% Cotton',
    ply: 1,
    warpCount: 20,
    weftCount: 16,
    endsPerInch: 60,
    picksPerInch: 52,
    width: 63,
    weave: 'Plain',
    selvedge: 'Plain',
    writing: 'SadeedTex',
    warpShrinkagePct: 8,
    weftShrinkagePct: 6,
    warpWastagePct: 3,
    weftWastagePct: 2,
    warpYarnRate: 350,
    weftYarnRate: 330,
    sizingCostPerKg: 25,
    commissionPct: 2.5,
    offGradePct: 1,
    offGradeRecovery: 0.5,
    loomRpm: 600,
    loomEfficiencyPct: 85,
    pickInsertion: 1,
    widthsPerLoom: 1,
    numberOfLooms: 10,
    totalOrder: 50000,
    inputInflow: 0,
    targetPrice: 0,
    perPickRate: 0,
    packingCost: 1.5,
    freightCost: 2,
  );

  print(example);
  print('Has additional yarn? ${example.hasAdditionalYarn}');

  final roundTrip = InputModel.fromJson(example.toJson());
  print('Round-trip matches: ${roundTrip.toJson().toString() == example.toJson().toString()}');
}