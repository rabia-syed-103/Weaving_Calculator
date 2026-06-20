/// calculation_engine_test.dart
/// -----------------------------------------------------------------------
/// Unit tests for CalculationEngine.calculate(), checked against a real
/// worked example pulled directly from Costing_InFlow_PerPick.xlsm
/// (sheet: "Costing", no Additional Yarn used in this example).
///
/// Every expected value below is copied from that sheet's live cached
/// cell values — not recalculated by hand — so this test is the actual
/// source of truth Rabia's calculation_engine.dart comment refers to.
///
/// Floating point comparisons use closeTo() with a small tolerance
/// instead of equals(), since Dart's double arithmetic can differ from
/// Excel's in the last few decimal digits even when both are "correct".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:costing_calculator/models/input_model.dart';
import 'package:costing_calculator/calculations/calculation_engine.dart';

void main() {
  // -----------------------------------------------------------------
  // Worked example input — copied from the "Costing" sheet's yellow
  // input cells. No Additional Yarn block used (all those fields left
  // null), so the additional-yarn outputs are all expected to be 0.
  // -----------------------------------------------------------------
  final input = InputModel(
    warpBlend: '60/2 Ctn',
    ply: 2,
    warpCount: 60,
    weftCount: 60,
    endsPerInch: 102,
    picksPerInch: 86,
    width: 61,
    weave: '1/1',
    selvedge: 'Leno',
    writing: 'Non',
    warpShrinkagePct: 15,
    weftShrinkagePct: 7,
    warpWastagePct: 3,
    weftWastagePct: 3,
    warpYarnRate: 6600,
    weftYarnRate: 6600,
    sizingCostPerKg: 61.17765,
    commissionPct: 1,
    offGradePct: 1,
    offGradeRecovery: 50,
    loomRpm: 750,
    loomEfficiencyPct: 90,
    pickInsertion: 1,
    widthsPerLoom: 2,
    numberOfLooms: 5,
    totalOrder: 50000,
    inputInflow: 25000,
    targetPrice: 244.42,
    perPickRate: 0,
    inputPerPick: 0.691512,
    packingCost: 0,
    freightCost: 0,
  );

  // sizingCostPerKg is passed separately to calculate(), matching how
  // SizingRatesRepository resolves it before calling the engine. Using
  // the same value as input.sizingCostPerKg here since that's what the
  // live sheet's VLOOKUP resolved to for 60/2 Ctn.
  final output = CalculationEngine.calculate(
    input: input,
    sizingCostPerKg: 61.17765,
  );

  // Tolerance for floating point comparisons. 0.0001 is tight enough to
  // catch real formula bugs but loose enough to absorb Dart-vs-Excel
  // last-digit rounding differences.
  const tol = 0.0001;

  group('CalculationEngine — Yarn Weight (Shrinkage + Wastage)', () {
    test('Warp Weight (S+W)', () {
      expect(output.warpWeightShrinkageWastage, closeTo(0.1609, tol));
    });

    test('Weft Weight (S+W)', () {
      expect(output.weftWeightShrinkageWastage, closeTo(0.1265, tol));
    });

    test('Additional Warp/Weft Weight (S+W) — no additional yarn used', () {
      expect(output.additionalWarpWeightShrinkageWastage, equals(0));
      expect(output.additionalWeftWeightShrinkageWastage, equals(0));
    });
  });

  group('CalculationEngine — Yarn Weight (Only Shrinkage)', () {
    test('Warp Weight (Only Shrinkage)', () {
      expect(output.warpWeightOnlyShrinkage, closeTo(0.15526, tol));
    });

    test('Weft Weight (Only Shrinkage)', () {
      expect(output.weftWeightOnlyShrinkage, closeTo(0.1218, tol));
    });

    test('Warp KG/Mtr', () {
      expect(output.warpKgPerMtr, closeTo(0.070425474, tol));
    });
  });

  group('CalculationEngine — Fabric Cost', () {
    test('Yarn Warp Cost', () {
      expect(output.yarnWarpCost, closeTo(106.194, tol));
    });

    test('Yarn Weft Cost', () {
      expect(output.yarnWeftCost, closeTo(83.49, tol));
    });

    test('Total Yarn Cost', () {
      expect(output.totalYarnCost, closeTo(189.684, tol));
    });

    test('Sizing Cost Per Mtr', () {
      expect(output.sizingCostPerMtr, closeTo(4.308465, tol));
    });

    test('Weaving Cost', () {
      expect(output.weavingCost, closeTo(59.470032, tol));
    });

    test('Off Grade Cost', () {
      expect(output.offGradePct, closeTo(0.05, tol));
    });

    test('Commission Cost', () {
      expect(output.commissionCost, closeTo(2.49204032, tol));
    });

    test('GREY FABRIC RATE (headline output)', () {
      expect(output.greyFabricRate, closeTo(251.69607232, tol));
    });
  });

  group('CalculationEngine — Production & Requirements', () {
    test('Per Day Per Loom Production', () {
      expect(output.perDayPerLoomProduction, closeTo(568.417695, tol));
    });

    test('LOOM IN FLOW (headline output)', () {
      expect(output.loomInFlow, closeTo(29909.870067, 0.001));
    });

    test('Daily Production — all looms', () {
      expect(output.dailyProductionAllLooms, closeTo(2842.088475, tol));
    });

    test('Days Required for Completion', () {
      expect(output.daysRequiredForCompletion, closeTo(17.592696, tol));
    });

    test('Warp Bags Required', () {
      expect(output.warpBagsRequired, closeTo(8045.0, tol));
    });

    test('Weft Bags Required', () {
      expect(output.weftBagsRequired, closeTo(6325.0, tol));
    });

    test('2nd Warp/Weft Bags Required — no additional yarn used', () {
      expect(output.secondWarpBagsRequired, equals(0));
      expect(output.secondWeftBagsRequired, equals(0));
    });
  });

  group('CalculationEngine — Cover Factor, Reed Space, Tape Length', () {
    test('Cover Factor — Warp', () {
      expect(output.coverFactorWarp, closeTo(13.168143, tol));
    });

    test('Cover Factor — Weft', () {
      expect(output.coverFactorWeft, closeTo(11.102552, tol));
    });

    test('Cover Factor — 2nd Warp/Weft — no additional yarn used', () {
      expect(output.coverFactorSecondWarp, equals(0));
      expect(output.coverFactorSecondWeft, equals(0));
    });

    test('Total Cover Factor', () {
      expect(output.totalCoverFactor, closeTo(24.270696, tol));
    });

    test('Reed Space (inches)', () {
      expect(output.reedSpaceInches, closeTo(64.689796, tol));
    });

    test('Tape Length (m)', () {
      expect(output.tapeLengthMtr, closeTo(104.3, tol));
    });

    test('Wt Grams per Metre', () {
      expect(output.wtGramsPerMetre, closeTo(0.125674, tol));
    });

    test('Container — 20ft (Mtrs)', () {
      expect(output.container20ftMtrs, closeTo(103443.0, tol));
    });

    test('Container — 40ft (Mtrs)', () {
      expect(output.container40ftMtrs, closeTo(206885.151231, tol));
    });
  });

  group('CalculationEngine — edge cases', () {
    test('Total Picks with no additional yarn equals Picks Per Inch', () {
      expect(output.totalPicks, equals(86));
    });

    test('hasAdditionalYarn is false for this example', () {
      expect(input.hasAdditionalYarn, isFalse);
    });
  });
}