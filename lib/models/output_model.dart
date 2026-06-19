/// OutputModel
/// -----------------------------------------------------------------------
/// Holds every calculated output field produced by calculation_engine.dart
/// from a given InputModel. Mirrors the structure of the Fabric Costing
/// Sheet outputs (Sections B, C, D in the field reference doc, and
/// Section 3 in the project manual).
///
/// All fields are `double` for the same reason as InputModel — costing
/// outputs (rates, weights, days, picks) are rarely whole numbers.
/// `completionDate` is the one exception, stored as DateTime since it's
/// a calendar date, not a number.
///
/// Fields tied to Additional Yarn (the "2nd warp/weft" outputs) are NOT
/// nullable here, unlike InputModel's additional fields. The formulas
/// already resolve "no additional yarn" down to 0 (see the IF(...,0)
/// branches in the field reference doc), so by the time a value reaches
/// OutputModel it's always a real number — 0 just means "not applicable".
library;

class OutputModel {
  // ---------------------------------------------------------------------
  // Headline outputs — always visible on the main screen
  // ---------------------------------------------------------------------
  final double greyFabricRate;
  final double loomInFlow;

  // ---------------------------------------------------------------------
  // Tab: Fabric Cost
  // ---------------------------------------------------------------------
  final double yarnWarpCost;
  final double yarnWeftCost;
  final double totalYarnCost;
  final double sizingCostPerMtr;
  final double weavingCost;
  final double offGradePct;
  final double commissionCost;

  // ---------------------------------------------------------------------
  // Tab: Yarn Weight
  // ---------------------------------------------------------------------
  final double warpWeightShrinkageWastage;
  final double weftWeightShrinkageWastage;
  final double additionalWarpWeightShrinkageWastage;
  final double additionalWeftWeightShrinkageWastage;
  final double warpWeightOnlyShrinkage;
  final double weftWeightOnlyShrinkage;
  final double additionalWarpWeightOnlyShrinkage;
  final double additionalWeftWeightOnlyShrinkage;
  final double warpKgPerMtr;

  // ---------------------------------------------------------------------
  // Tab: Production & Requirements
  // ---------------------------------------------------------------------
  final double totalPicks;
  final double perDayPerLoomProduction;
  final double dailyProductionAllLooms;
  final double daysRequiredForCompletion;
  final DateTime completionDate;
  final double warpBagsRequired;
  final double secondWarpBagsRequired;
  final double weftBagsRequired;
  final double secondWeftBagsRequired;

  // ---------------------------------------------------------------------
  // Tab: Cover Factor, Reed Space & Tape Length
  // ---------------------------------------------------------------------
  final double coverFactorWarp;
  final double coverFactorSecondWarp;
  final double coverFactorWeft;
  final double coverFactorSecondWeft;
  final double totalCoverFactor;
  final double reedSpaceInches;
  final double tapeLengthMtr;
  final double wtGramsPerMetre;
  final double container20ftMtrs;
  final double container40ftMtrs;

  const OutputModel({
    required this.greyFabricRate,
    required this.loomInFlow,
    required this.yarnWarpCost,
    required this.yarnWeftCost,
    required this.totalYarnCost,
    required this.sizingCostPerMtr,
    required this.weavingCost,
    required this.offGradePct,
    required this.commissionCost,
    required this.warpWeightShrinkageWastage,
    required this.weftWeightShrinkageWastage,
    required this.additionalWarpWeightShrinkageWastage,
    required this.additionalWeftWeightShrinkageWastage,
    required this.warpWeightOnlyShrinkage,
    required this.weftWeightOnlyShrinkage,
    required this.additionalWarpWeightOnlyShrinkage,
    required this.additionalWeftWeightOnlyShrinkage,
    required this.warpKgPerMtr,
    required this.totalPicks,
    required this.perDayPerLoomProduction,
    required this.dailyProductionAllLooms,
    required this.daysRequiredForCompletion,
    required this.completionDate,
    required this.warpBagsRequired,
    required this.secondWarpBagsRequired,
    required this.weftBagsRequired,
    required this.secondWeftBagsRequired,
    required this.coverFactorWarp,
    required this.coverFactorSecondWarp,
    required this.coverFactorWeft,
    required this.coverFactorSecondWeft,
    required this.totalCoverFactor,
    required this.reedSpaceInches,
    required this.tapeLengthMtr,
    required this.wtGramsPerMetre,
    required this.container20ftMtrs,
    required this.container40ftMtrs,
  });

  // ---------------------------------------------------------------------
  // copyWith — handy for tests where you want to tweak one output value
  // without rebuilding the whole object.
  // ---------------------------------------------------------------------
  OutputModel copyWith({
    double? greyFabricRate,
    double? loomInFlow,
    double? yarnWarpCost,
    double? yarnWeftCost,
    double? totalYarnCost,
    double? sizingCostPerMtr,
    double? weavingCost,
    double? offGradePct,
    double? commissionCost,
    double? warpWeightShrinkageWastage,
    double? weftWeightShrinkageWastage,
    double? additionalWarpWeightShrinkageWastage,
    double? additionalWeftWeightShrinkageWastage,
    double? warpWeightOnlyShrinkage,
    double? weftWeightOnlyShrinkage,
    double? additionalWarpWeightOnlyShrinkage,
    double? additionalWeftWeightOnlyShrinkage,
    double? warpKgPerMtr,
    double? totalPicks,
    double? perDayPerLoomProduction,
    double? dailyProductionAllLooms,
    double? daysRequiredForCompletion,
    DateTime? completionDate,
    double? warpBagsRequired,
    double? secondWarpBagsRequired,
    double? weftBagsRequired,
    double? secondWeftBagsRequired,
    double? coverFactorWarp,
    double? coverFactorSecondWarp,
    double? coverFactorWeft,
    double? coverFactorSecondWeft,
    double? totalCoverFactor,
    double? reedSpaceInches,
    double? tapeLengthMtr,
    double? wtGramsPerMetre,
    double? container20ftMtrs,
    double? container40ftMtrs,
  }) {
    return OutputModel(
      greyFabricRate: greyFabricRate ?? this.greyFabricRate,
      loomInFlow: loomInFlow ?? this.loomInFlow,
      yarnWarpCost: yarnWarpCost ?? this.yarnWarpCost,
      yarnWeftCost: yarnWeftCost ?? this.yarnWeftCost,
      totalYarnCost: totalYarnCost ?? this.totalYarnCost,
      sizingCostPerMtr: sizingCostPerMtr ?? this.sizingCostPerMtr,
      weavingCost: weavingCost ?? this.weavingCost,
      offGradePct: offGradePct ?? this.offGradePct,
      commissionCost: commissionCost ?? this.commissionCost,
      warpWeightShrinkageWastage:
          warpWeightShrinkageWastage ?? this.warpWeightShrinkageWastage,
      weftWeightShrinkageWastage:
          weftWeightShrinkageWastage ?? this.weftWeightShrinkageWastage,
      additionalWarpWeightShrinkageWastage:
          additionalWarpWeightShrinkageWastage ??
              this.additionalWarpWeightShrinkageWastage,
      additionalWeftWeightShrinkageWastage:
          additionalWeftWeightShrinkageWastage ??
              this.additionalWeftWeightShrinkageWastage,
      warpWeightOnlyShrinkage:
          warpWeightOnlyShrinkage ?? this.warpWeightOnlyShrinkage,
      weftWeightOnlyShrinkage:
          weftWeightOnlyShrinkage ?? this.weftWeightOnlyShrinkage,
      additionalWarpWeightOnlyShrinkage: additionalWarpWeightOnlyShrinkage ??
          this.additionalWarpWeightOnlyShrinkage,
      additionalWeftWeightOnlyShrinkage: additionalWeftWeightOnlyShrinkage ??
          this.additionalWeftWeightOnlyShrinkage,
      warpKgPerMtr: warpKgPerMtr ?? this.warpKgPerMtr,
      totalPicks: totalPicks ?? this.totalPicks,
      perDayPerLoomProduction:
          perDayPerLoomProduction ?? this.perDayPerLoomProduction,
      dailyProductionAllLooms:
          dailyProductionAllLooms ?? this.dailyProductionAllLooms,
      daysRequiredForCompletion:
          daysRequiredForCompletion ?? this.daysRequiredForCompletion,
      completionDate: completionDate ?? this.completionDate,
      warpBagsRequired: warpBagsRequired ?? this.warpBagsRequired,
      secondWarpBagsRequired:
          secondWarpBagsRequired ?? this.secondWarpBagsRequired,
      weftBagsRequired: weftBagsRequired ?? this.weftBagsRequired,
      secondWeftBagsRequired:
          secondWeftBagsRequired ?? this.secondWeftBagsRequired,
      coverFactorWarp: coverFactorWarp ?? this.coverFactorWarp,
      coverFactorSecondWarp:
          coverFactorSecondWarp ?? this.coverFactorSecondWarp,
      coverFactorWeft: coverFactorWeft ?? this.coverFactorWeft,
      coverFactorSecondWeft:
          coverFactorSecondWeft ?? this.coverFactorSecondWeft,
      totalCoverFactor: totalCoverFactor ?? this.totalCoverFactor,
      reedSpaceInches: reedSpaceInches ?? this.reedSpaceInches,
      tapeLengthMtr: tapeLengthMtr ?? this.tapeLengthMtr,
      wtGramsPerMetre: wtGramsPerMetre ?? this.wtGramsPerMetre,
      container20ftMtrs: container20ftMtrs ?? this.container20ftMtrs,
      container40ftMtrs: container40ftMtrs ?? this.container40ftMtrs,
    );
  }

  // ---------------------------------------------------------------------
  // JSON serialization — needed for Hive (Phase 5), same pattern as
  // InputModel. completionDate is stored as an ISO string and parsed
  // back with DateTime.parse.
  // ---------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'greyFabricRate': greyFabricRate,
      'loomInFlow': loomInFlow,
      'yarnWarpCost': yarnWarpCost,
      'yarnWeftCost': yarnWeftCost,
      'totalYarnCost': totalYarnCost,
      'sizingCostPerMtr': sizingCostPerMtr,
      'weavingCost': weavingCost,
      'offGradePct': offGradePct,
      'commissionCost': commissionCost,
      'warpWeightShrinkageWastage': warpWeightShrinkageWastage,
      'weftWeightShrinkageWastage': weftWeightShrinkageWastage,
      'additionalWarpWeightShrinkageWastage':
          additionalWarpWeightShrinkageWastage,
      'additionalWeftWeightShrinkageWastage':
          additionalWeftWeightShrinkageWastage,
      'warpWeightOnlyShrinkage': warpWeightOnlyShrinkage,
      'weftWeightOnlyShrinkage': weftWeightOnlyShrinkage,
      'additionalWarpWeightOnlyShrinkage': additionalWarpWeightOnlyShrinkage,
      'additionalWeftWeightOnlyShrinkage': additionalWeftWeightOnlyShrinkage,
      'warpKgPerMtr': warpKgPerMtr,
      'totalPicks': totalPicks,
      'perDayPerLoomProduction': perDayPerLoomProduction,
      'dailyProductionAllLooms': dailyProductionAllLooms,
      'daysRequiredForCompletion': daysRequiredForCompletion,
      'completionDate': completionDate.toIso8601String(),
      'warpBagsRequired': warpBagsRequired,
      'secondWarpBagsRequired': secondWarpBagsRequired,
      'weftBagsRequired': weftBagsRequired,
      'secondWeftBagsRequired': secondWeftBagsRequired,
      'coverFactorWarp': coverFactorWarp,
      'coverFactorSecondWarp': coverFactorSecondWarp,
      'coverFactorWeft': coverFactorWeft,
      'coverFactorSecondWeft': coverFactorSecondWeft,
      'totalCoverFactor': totalCoverFactor,
      'reedSpaceInches': reedSpaceInches,
      'tapeLengthMtr': tapeLengthMtr,
      'wtGramsPerMetre': wtGramsPerMetre,
      'container20ftMtrs': container20ftMtrs,
      'container40ftMtrs': container40ftMtrs,
    };
  }

  factory OutputModel.fromJson(Map<String, dynamic> json) {
    // Same helper pattern as InputModel.fromJson — handles int vs double
    // ambiguity coming back from JSON/Hive.
    double _d(dynamic v) => (v as num).toDouble();

    return OutputModel(
      greyFabricRate: _d(json['greyFabricRate']),
      loomInFlow: _d(json['loomInFlow']),
      yarnWarpCost: _d(json['yarnWarpCost']),
      yarnWeftCost: _d(json['yarnWeftCost']),
      totalYarnCost: _d(json['totalYarnCost']),
      sizingCostPerMtr: _d(json['sizingCostPerMtr']),
      weavingCost: _d(json['weavingCost']),
      offGradePct: _d(json['offGradePct']),
      commissionCost: _d(json['commissionCost']),
      warpWeightShrinkageWastage: _d(json['warpWeightShrinkageWastage']),
      weftWeightShrinkageWastage: _d(json['weftWeightShrinkageWastage']),
      additionalWarpWeightShrinkageWastage:
          _d(json['additionalWarpWeightShrinkageWastage']),
      additionalWeftWeightShrinkageWastage:
          _d(json['additionalWeftWeightShrinkageWastage']),
      warpWeightOnlyShrinkage: _d(json['warpWeightOnlyShrinkage']),
      weftWeightOnlyShrinkage: _d(json['weftWeightOnlyShrinkage']),
      additionalWarpWeightOnlyShrinkage:
          _d(json['additionalWarpWeightOnlyShrinkage']),
      additionalWeftWeightOnlyShrinkage:
          _d(json['additionalWeftWeightOnlyShrinkage']),
      warpKgPerMtr: _d(json['warpKgPerMtr']),
      totalPicks: _d(json['totalPicks']),
      perDayPerLoomProduction: _d(json['perDayPerLoomProduction']),
      dailyProductionAllLooms: _d(json['dailyProductionAllLooms']),
      daysRequiredForCompletion: _d(json['daysRequiredForCompletion']),
      completionDate: DateTime.parse(json['completionDate'] as String),
      warpBagsRequired: _d(json['warpBagsRequired']),
      secondWarpBagsRequired: _d(json['secondWarpBagsRequired']),
      weftBagsRequired: _d(json['weftBagsRequired']),
      secondWeftBagsRequired: _d(json['secondWeftBagsRequired']),
      coverFactorWarp: _d(json['coverFactorWarp']),
      coverFactorSecondWarp: _d(json['coverFactorSecondWarp']),
      coverFactorWeft: _d(json['coverFactorWeft']),
      coverFactorSecondWeft: _d(json['coverFactorSecondWeft']),
      totalCoverFactor: _d(json['totalCoverFactor']),
      reedSpaceInches: _d(json['reedSpaceInches']),
      tapeLengthMtr: _d(json['tapeLengthMtr']),
      wtGramsPerMetre: _d(json['wtGramsPerMetre']),
      container20ftMtrs: _d(json['container20ftMtrs']),
      container40ftMtrs: _d(json['container40ftMtrs']),
    );
  }

  @override
  String toString() => 'OutputModel(${toJson()})';
}

// ---------------------------------------------------------------------
// Example / sanity check — delete this once you've confirmed it compiles.
// Values here are placeholders, NOT calculated from the formulas yet —
// that's calculation_engine.dart's job (Phase 2, next step). This just
// proves the model itself builds, copies, and round-trips through JSON.
// Run with: dart run lib/models/output_model.dart
// ---------------------------------------------------------------------
void main() {
  final example = OutputModel(
    greyFabricRate: 142.50,
    loomInFlow: 38200,
    yarnWarpCost: 58.32,
    yarnWeftCost: 41.18,
    totalYarnCost: 99.50,
    sizingCostPerMtr: 6.20,
    weavingCost: 28.40,
    offGradePct: 2.10,
    commissionCost: 6.30,
    warpWeightShrinkageWastage: 0.085,
    weftWeightShrinkageWastage: 0.072,
    additionalWarpWeightShrinkageWastage: 0,
    additionalWeftWeightShrinkageWastage: 0,
    warpWeightOnlyShrinkage: 0.082,
    weftWeightOnlyShrinkage: 0.069,
    additionalWarpWeightOnlyShrinkage: 0,
    additionalWeftWeightOnlyShrinkage: 0,
    warpKgPerMtr: 0.037,
    totalPicks: 76,
    perDayPerLoomProduction: 320.5,
    dailyProductionAllLooms: 3205,
    daysRequiredForCompletion: 15.6,
    completionDate: DateTime(2026, 7, 6),
    warpBagsRequired: 4250,
    secondWarpBagsRequired: 0,
    weftBagsRequired: 3600,
    secondWeftBagsRequired: 0,
    coverFactorWarp: 17.1,
    coverFactorSecondWarp: 0,
    coverFactorWeft: 12.0,
    coverFactorSecondWeft: 0,
    totalCoverFactor: 29.1,
    reedSpaceInches: 64.4,
    tapeLengthMtr: 103.8,
    wtGramsPerMetre: 68.4,
    container20ftMtrs: 192,
    container40ftMtrs: 380,
  );

  print(example);

  final roundTrip = OutputModel.fromJson(example.toJson());
  print('Round-trip matches: '
      '${roundTrip.toJson().toString() == example.toJson().toString()}');
}