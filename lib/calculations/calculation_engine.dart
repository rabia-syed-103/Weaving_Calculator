/// calculation_engine.dart
/// -----------------------------------------------------------------------
/// Pure calculation functions that turn an InputModel (+ a Sizing Rate)
/// into a complete OutputModel. Every formula here was copied cell-by-cell
/// from Costing_InFlow_PerPick.xlsm (sheet: "Costing") and verified
/// against that workbook's own cached values — see
/// test/calculation_engine_test.dart for the exact worked example used
/// to confirm every single output below.
///
/// IMPORTANT — Sizing Cost Per Kg is NOT calculated in here.
/// In the Excel sheet, B17 = VLOOKUP(WarpCount/Ply Blend, 'Sizing Rates'!...).
/// In the app, that lookup is done by SizingRatesRepository (see
/// sizing_rates_repository.dart) *before* calling calculate(). This file
/// just receives the looked-up rate as a plain double, the same way the
/// Excel formulas receive c_Sizing_Cost_Per_Kg as a resolved number.
///
/// No UI code, no async, no I/O in this file — keep it that way so it
/// stays trivially unit-testable.
library;

import 'dart:math';
import '../models/input_model.dart';
import '../models/output_model.dart';

class CalculationEngine {
  /// Runs every formula and returns a fully-populated OutputModel.
  ///
  /// [input] — the user's entered values.
  /// [sizingCostPerKg] — resolved separately via SizingRatesRepository
  ///   (Warp Count + Ply + Blend lookup). Passed in here as a plain
  ///   number, matching how the Excel sheet treats c_Sizing_Cost_Per_Kg
  ///   once VLOOKUP has already resolved it.
  static OutputModel calculate({
    required InputModel input,
    required double sizingCostPerKg,
  }) {
    // ---------------------------------------------------------------
    // Section B / Yarn Weight (Shrinkage + Wastage)  — Excel B33:B36
    // ---------------------------------------------------------------
    final warpWeightSW = _round(
      input.endsPerInch *
          input.width *
          ((1 + input.warpShrinkagePct / 100) + (input.warpWastagePct / 100)) /
          (768.1 * input.warpCount) /
          (1 - input.offGradePct / 100),
      4,
    );

    final weftWeightSW = _round(
      input.picksPerInch *
          input.width *
          (1 + input.weftShrinkagePct / 100 + input.weftWastagePct / 100) /
          (768.1 * input.weftCount) /
          (1 - input.offGradePct / 100),
      4,
    );

    final hasAddWarp = (input.additionalWarpCount ?? 0) > 0;
    final hasAddWeft = (input.additionalWeftCount ?? 0) > 0;

    final addWarpWeightSW = hasAddWarp
        ? _round(
      (input.additionalEndsPerInch ?? 0) *
          input.width *
          (1 +
              (input.additionalWarpShrinkagePct ?? 0) / 100 +
              (input.additionalWarpWastagePct ?? 0) / 100) /
          (768.1 * (input.additionalWarpCount ?? 1)) /
          (1 - input.offGradePct / 100),
      4,
    )
        : 0.0;

    final addWeftWeightSW = hasAddWeft
        ? _round(
      (input.additionalPicksPerInch ?? 0) *
          input.width *
          (1 +
              (input.additionalWeftShrinkagePct ?? 0) / 100 +
              (input.additionalWeftWastagePct ?? 0) / 100) /
          (768.1 * (input.additionalWeftCount ?? 1)) /
          (1 - input.offGradePct / 100),
      4,
    )
        : 0.0;

    // ---------------------------------------------------------------
    // Yarn Weight (Only Shrinkage) — Excel B38:B41
    // ---------------------------------------------------------------
    final warpWeightOS = _round(
      input.endsPerInch *
          input.width *
          (1 + input.warpShrinkagePct / 100) /
          (768.1 * input.warpCount),
      5,
    );

    final weftWeightOS = _round(
      input.picksPerInch *
          input.width *
          (1 + input.weftShrinkagePct / 100) /
          (768.1 * input.weftCount),
      5,
    );

    final hasAddWarpEnds =
        hasAddWarp && (input.additionalEndsPerInch ?? 0) > 0;
    final hasAddWeftPicks =
        hasAddWeft && (input.additionalPicksPerInch ?? 0) > 0;

    final addWarpWeightOS = hasAddWarpEnds
        ? _round(
      (input.additionalEndsPerInch ?? 0) *
          input.width *
          (1 + (input.additionalWarpShrinkagePct ?? 0) / 100) /
          (768.1 * (input.additionalWarpCount ?? 1)),
      5,
    )
        : 0.0;

    final addWeftWeightOS = hasAddWeftPicks
        ? _round(
      (input.additionalPicksPerInch ?? 0) *
          input.width *
          (1 + (input.additionalWeftShrinkagePct ?? 0) / 100) /
          (768.1 * (input.additionalWeftCount ?? 1)),
      5,
    )
        : 0.0;

    // Excel B42: =(B38+B40)/2.2046  -> Warp Weight(OnlyShrink) + Additional Warp Weight(OnlyShrink)
    final warpKgPerMtr = (warpWeightOS + addWarpWeightOS) / 2.2046;

    // ---------------------------------------------------------------
    // Section B — Fabric Cost  — Excel H3:H12
    // ---------------------------------------------------------------
    final yarnWarpCost = (input.warpYarnRate / 10 * warpWeightSW) +
        ((input.additionalWarpYarnRate ?? 0) / 10 * addWarpWeightSW);

    final yarnWeftCost = (input.weftYarnRate / 10 * weftWeightSW) +
        ((input.additionalWeftYarnRate ?? 0) / 10 * addWeftWeightSW);

    final totalYarnCost = yarnWarpCost + yarnWeftCost;

    // Excel H6: =B42*c_Sizing_Cost_Per_Kg
    final sizingCostPerMtr = warpKgPerMtr * sizingCostPerKg;

    // Excel A31/B31: =+B6+E6  (Picks Per Inch + Additional Picks Per Inch)
    final totalPicks = input.picksPerInch + (input.additionalPicksPerInch ?? 0);

    // Excel H7: =c_In_Put_Per_Pick*B31
    final weavingCost = input.inputPerPick * totalPicks;

    // Excel H8: =ROUND(SUM(c_Sizing_Cost_Per_Mtr,0.4)*c_Off_Grade/100,2)
    // The "0.4" is a deliberate flat addition in the original sheet —
    // verified against the workbook's cached value, not a typo.
    final offGradeCost = _round((sizingCostPerMtr + 0.4) * input.offGradePct / 100, 2);

    final packingCost = input.packingCost;
    final freightCost = input.freightCost;

    // Excel H11: =(H5+SUM(H7:H10))*c_Commission_Rate/100
    //   H5 = Total Yarn Cost, H7=Weaving, H8=Off Grade Cost, H9=Packing, H10=Freight
    //   NOTE: Commission Cost is excluded from its own base.
    final commissionCost =
        (totalYarnCost + (weavingCost + offGradeCost + packingCost + freightCost)) *
            input.commissionPct /
            100;

    // Excel H19: =c_Total_Yarn_Cost+SUM(H7:H11)
    final greyFabricRate = totalYarnCost +
        (weavingCost + offGradeCost + packingCost + freightCost + commissionCost);

    // ---------------------------------------------------------------
    // Section C — Production, Completion, Yarn Requirement — Excel K3:K10
    // ---------------------------------------------------------------
    // Excel K3
    final perDayPerLoomProduction = _round(
      (1440 / 39.37) *
          (input.loomRpm *
              input.loomEfficiencyPct /
              100 *
              input.pickInsertion *
              input.widthsPerLoom) /
          totalPicks *
          (1 - input.offGradePct / 100),
      6,
    );

    // Excel H20: =(H7-c_Sizing_Cost_Per_Mtr-c_Off_Grade_Cost-c_Packing_Cost-c_Freight_Cost-H11)*Per_Day_Per_Loom_Prodcution
    // NOTE: this is literal from the sheet — Loom In Flow is a per-day
    // cost differential multiplied by daily production, not a simple cost.
    final loomInFlow = (weavingCost -
        sizingCostPerMtr -
        offGradeCost -
        packingCost -
        freightCost -
        commissionCost) *
        perDayPerLoomProduction;

    // Excel K4: =c_No._of_Looms*Per_Day_Per_Loom_Prodcution
    final dailyProductionAllLooms = input.numberOfLooms * perDayPerLoomProduction;

    // Excel K5: =c_Total_Order/K4
    final daysRequiredForCompletion = input.totalOrder / dailyProductionAllLooms;

    // Excel K6: =K5+NOW()
    final completionDate = DateTime.now().add(
      Duration(
        milliseconds: (daysRequiredForCompletion * 24 * 60 * 60 * 1000).round(),
      ),
    );

    // Excel K7:K10
    final warpBagsRequired = input.totalOrder * warpWeightSW;
    final secondWarpBagsRequired = input.totalOrder * addWarpWeightSW;
    final weftBagsRequired = input.totalOrder * weftWeightSW;
    final secondWeftBagsRequired = input.totalOrder * addWeftWeightSW;

    // ---------------------------------------------------------------
    // Section D — Cover Factor, Reed Space, Tape Length — Excel N3:N12
    // ---------------------------------------------------------------
    final coverFactorWarp = input.endsPerInch / sqrt(input.warpCount);
    final coverFactorSecondWarp = hasAddWarp
        ? (input.additionalEndsPerInch ?? 0) /
        sqrt(input.additionalWarpCount ?? 1)
        : 0.0;
    final coverFactorWeft = input.picksPerInch / sqrt(input.weftCount);
    final coverFactorSecondWeft = hasAddWeft
        ? (input.additionalPicksPerInch ?? 0) /
        sqrt(input.additionalWeftCount ?? 1)
        : 0.0;

    // Excel N7: =SUM(N3:N6)
    final totalCoverFactor =
        coverFactorWarp + coverFactorSecondWarp + coverFactorWeft + coverFactorSecondWeft;

    // Excel N8: =IF(c_Width>0,(c_Ends_Per_Inch*c_Width)/(c_Ends_Per_Inch-4)+1.2,0)
    final reedSpaceInches = input.width > 0
        ? (input.endsPerInch * input.width) / (input.endsPerInch - 4) + 1.2
        : 0.0;

    // Excel N9: =+c_Picks_Per_Inch*3/C_Weft_Count+100
    final tapeLengthMtr = input.picksPerInch * 3 / input.weftCount + 100;

    // Excel N10: =(B38+B39+B40+B41)/2.2046
    //   i.e. Warp Weight(OS) + Weft Weight(OS) + AddWarp(OS) + AddWeft(OS)
    final wtGramsPerMetre =
        (warpWeightOS + weftWeightOS + addWarpWeightOS + addWeftWeightOS) / 2.2046;

    // Excel N11: =ROUND(13000/N10+(N10*3)/100,0)
    final container20ftMtrs = _round(
      13000 / wtGramsPerMetre + (wtGramsPerMetre * 3) / 100,
      0,
    );

    // Excel N12: =26000/N10
    final container40ftMtrs = 26000 / wtGramsPerMetre;

    return OutputModel(
      greyFabricRate: greyFabricRate,
      loomInFlow: loomInFlow,
      yarnWarpCost: yarnWarpCost,
      yarnWeftCost: yarnWeftCost,
      totalYarnCost: totalYarnCost,
      sizingCostPerMtr: sizingCostPerMtr,
      weavingCost: weavingCost,
      offGradePct: offGradeCost,
      commissionCost: commissionCost,
      warpWeightShrinkageWastage: warpWeightSW,
      weftWeightShrinkageWastage: weftWeightSW,
      additionalWarpWeightShrinkageWastage: addWarpWeightSW,
      additionalWeftWeightShrinkageWastage: addWeftWeightSW,
      warpWeightOnlyShrinkage: warpWeightOS,
      weftWeightOnlyShrinkage: weftWeightOS,
      additionalWarpWeightOnlyShrinkage: addWarpWeightOS,
      additionalWeftWeightOnlyShrinkage: addWeftWeightOS,
      warpKgPerMtr: warpKgPerMtr,
      totalPicks: totalPicks,
      perDayPerLoomProduction: perDayPerLoomProduction,
      dailyProductionAllLooms: dailyProductionAllLooms,
      daysRequiredForCompletion: daysRequiredForCompletion,
      completionDate: completionDate,
      warpBagsRequired: warpBagsRequired,
      secondWarpBagsRequired: secondWarpBagsRequired,
      weftBagsRequired: weftBagsRequired,
      secondWeftBagsRequired: secondWeftBagsRequired,
      coverFactorWarp: coverFactorWarp,
      coverFactorSecondWarp: coverFactorSecondWarp,
      coverFactorWeft: coverFactorWeft,
      coverFactorSecondWeft: coverFactorSecondWeft,
      totalCoverFactor: totalCoverFactor,
      reedSpaceInches: reedSpaceInches,
      tapeLengthMtr: tapeLengthMtr,
      wtGramsPerMetre: wtGramsPerMetre,
      container20ftMtrs: container20ftMtrs,
      container40ftMtrs: container40ftMtrs,
    );
  }

  /// Mimics Excel's ROUND() — round-half-away-from-zero, to [digits]
  /// decimal places. Dart's num.toStringAsFixed / double rounding uses
  /// round-half-to-even in some cases, which can disagree with Excel
  /// at the last decimal digit, so this is implemented explicitly.
  static double _round(double value, int digits) {
    final mult = pow(10, digits);
    return (value * mult).round() / mult;
  }
}

/// ---------------------------------------------------------------------
/// USAGE — once SizingRatesRepository has resolved a rate:
///
///   final rate = SizingRatesRepository.instance.lookup(
///     count: input.warpCount, ply: input.ply, blend: input.warpBlend,
///   );
///   final output = CalculationEngine.calculate(
///     input: input,
///     sizingCostPerKg: rate!.perKg,
///   );
/// ---------------------------------------------------------------------