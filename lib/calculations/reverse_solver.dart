/// reverse_solver.dart
/// -----------------------------------------------------------------------
/// Ports two VBA macros from the original Excel workbook
/// (Costing_InFlow_PerPick.xlsm) LITERALLY — same cell reads, same
/// algebra, same rounding, same validation messages. These are NOT
/// derived from calculation_engine.dart's forward formulas; they are a
/// separate reverse-solve the original spreadsheet used, triggered by a
/// button/macro rather than running on every keystroke.
///
/// ORIGINAL VBA: Calculate_Per_Pick_Costing() and Target_Price()
///
/// WHAT THESE DO
/// Both solve backwards for Input Per Pick (B18) so that either:
///   - Loom In Flow matches what the user typed into Input Inflow, or
///   - Grey Fabric Rate matches what the user typed into Target Price.
/// Only one mode is "active" at a time (mirrors the VBA's C20 mode flag:
/// "InFlow" or "TargetPrice"). After solving, the resulting Input Per
/// Pick is written back into the form, and a NORMAL forward recalculation
/// (CalculationEngine.calculate) runs from there — exactly like the VBA
/// macro ends with Application.Calculate.
///
/// IMPORTANT — these formulas reference vSizing, vOffGrade etc. taken
/// DIRECTLY from fixed Excel cells (H6, H8, H9, H10) that do NOT depend
/// on the very value being solved for (B18/Input Per Pick). In Dart,
/// the equivalent "fixed" values are computed by calling
/// CalculationEngine.calculate() ONCE with the user's current
/// inputPerPick (any placeholder value works, e.g. 0) just to read off
/// totalYarnCost, sizingCostPerMtr, offGradePct (cost), and
/// perDayPerLoomProduction — none of which actually depend on
/// inputPerPick. This mirrors the VBA's "read fixed cells only" comment.
///
/// Do NOT "simplify" or "fix" the algebra here even if it looks
/// inconsistent with calculation_engine.dart's own greyFabricRate
/// formula (e.g. Target Price mode subtracts sizing where the forward
/// formula doesn't include it) — this is the original spreadsheet's own
/// macro logic, kept byte-for-byte intentional per direct instruction.
library;

import '../calculations/calculation_engine.dart';
import '../models/input_model.dart';

enum SolverMode { inFlow, targetPrice }

class ReverseSolverResult {
  final double? inputPerPick;
  final String? errorMessage;

  const ReverseSolverResult.success(this.inputPerPick) : errorMessage = null;
  const ReverseSolverResult.error(this.errorMessage) : inputPerPick = null;

  bool get isError => errorMessage != null;
}

class ReverseSolver {
  /// Mirrors VBA Sub Calculate_Per_Pick_Costing().
  /// Solves Input Per Pick so that Loom In Flow == [inputInflow].
  static ReverseSolverResult solveForInFlow({
    required InputModel input,
    required double sizingCostPerKg,
    required double inputInflow,
  }) {
    // Read "fixed" values the same way the VBA macro does — via a normal
    // forward calculate() call using the input as-is. None of the values
    // we read below (totalYarnCost, sizingCostPerMtr, offGradePct cost,
    // perDayPerLoomProduction, totalPicks) depend on inputPerPick, so
    // it's safe to read them off any calculate() result.
    final fixed = CalculationEngine.calculate(input: input, sizingCostPerKg: sizingCostPerKg);

    final vInFlow = _round(inputInflow, 2);
    final vPerDay = _round(fixed.perDayPerLoomProduction, 6);
    final vYarn = _round(fixed.totalYarnCost, 2);
    final vSizing = _round(fixed.sizingCostPerMtr, 2);
    final vOffGrade = _round(fixed.offGradePct, 2); // offGradePct field holds the Off Grade COST, not a percent — see OutputModel
    final vPacking = _round(input.packingCost, 2);
    final vFreight = _round(input.freightCost, 6);
    final vCommRate = _round(input.commissionPct, 4) / 100;
    final vPicks = _round(fixed.totalPicks, 2);

    if (vPicks == 0) {
      return const ReverseSolverResult.error('Total Picks is zero!');
    }
    if (vPerDay == 0) {
      return const ReverseSolverResult.error('Per Day Production is zero!');
    }
    if (vCommRate >= 1) {
      return const ReverseSolverResult.error('Commission looks wrong — enter e.g. 2 for 2%');
    }

    final vW = (vInFlow / vPerDay +
        vSizing +
        (vOffGrade + vPacking + vFreight) * (1 + vCommRate) +
        vYarn * vCommRate) /
        (1 - vCommRate);

    final vResult = vW / vPicks;
    return ReverseSolverResult.success(_round(vResult, 6));
  }

  /// Mirrors VBA Sub Target_Price().
  /// Solves Input Per Pick so that Grey Fabric Rate == [targetPrice].
  ///
  /// BUG FIX (verified against the actual VBA source): the original
  /// Target_Price() macro has its vSizing read commented out —
  ///   '        vSizing = Round(.Range("H6").Value, 2)
  /// — so vSizing stays at VBA's Dim default of 0 for this Sub. This is
  /// DIFFERENT from solveForInFlow() above, which DOES read vSizing.
  /// Earlier versions of this file read sizingCostPerMtr here too,
  /// which caused Target Price mode to be off by a constant amount
  /// (verified: ~8 unit gap in Input Per Pick, traced directly to this
  /// line). Do not "fix" this by reading sizingCostPerMtr again — it is
  /// intentionally 0 here, matching the commented-out VBA line exactly.
  static ReverseSolverResult solveForTargetPrice({
    required InputModel input,
    required double sizingCostPerKg,
    required double targetPrice,
  }) {
    final fixed = CalculationEngine.calculate(input: input, sizingCostPerKg: sizingCostPerKg);

    final vTarget = _round(targetPrice, 4);
    final vYarn = _round(fixed.totalYarnCost, 2);
    const vSizing = 0.0; // VBA's read of this is commented out — stays at Dim default 0
    final vOffGrade = _round(fixed.offGradePct, 2);
    final vPacking = _round(input.packingCost, 2);
    final vFreight = _round(input.freightCost, 6);
    final vCommRate = _round(input.commissionPct, 4) / 100;
    final vPicks = _round(fixed.totalPicks, 4);

    if (vPicks == 0) {
      return const ReverseSolverResult.error('Total Picks is zero!');
    }
    if (vCommRate >= 1) {
      return const ReverseSolverResult.error('Commission looks wrong — enter e.g. 2 for 2%');
    }
    if (vTarget == 0) {
      return const ReverseSolverResult.error('Target Price is zero!');
    }

    final vMinCost = (vYarn + vOffGrade + vPacking + vFreight) * (1 + vCommRate);
    if (vTarget <= vMinCost) {
      return ReverseSolverResult.error(
        'Target Price too low to cover costs.\nMinimum = ${vMinCost.toStringAsFixed(2)}',
      );
    }

    final vS = vYarn + vOffGrade + vPacking + vFreight;
    final vW = vTarget / (1 + vCommRate) - vS - vSizing / (1 + vCommRate);

    final vResult = vW / vPicks;
    return ReverseSolverResult.success(_round(vResult, 6));
  }

  /// Excel ROUND() — round-half-away-from-zero. Same helper as
  /// calculation_engine.dart's _round, duplicated here so this file has
  /// no dependency on that private function.
  static double _round(double value, int digits) {
    final mult = _pow10(digits);
    return (value * mult).round() / mult;
  }

  static double _pow10(int digits) {
    double result = 1;
    for (var i = 0; i < digits; i++) {
      result *= 10;
    }
    return result;
  }
}

/// ---------------------------------------------------------------------
/// USAGE — wire this to two buttons next to Input Inflow and Target
/// Price (NOT live on every keystroke, same as the VBA — it's a
/// deliberate "Calculate" action, not a passive listener):
///
///   final result = ReverseSolver.solveForInFlow(
///     input: currentInput,
///     sizingCostPerKg: rate.perKg,
///     inputInflow: double.parse(_controllers['inputInflow']!.text),
///   );
///   if (result.isError) {
///     // show result.errorMessage to the user (e.g. SnackBar/dialog)
///   } else {
///     _controllers['inputPerPick']!.text = result.inputPerPick!.toString();
///     _recalculate(); // normal forward pass — mirrors VBA's trailing
///                      // Application.Calculate
///   }
///
/// Mode flag: track which mode was last used (inFlow vs targetPrice) the
/// same way C20 does in Excel, if you need to warn the user before
/// switching modes (the VBA's MsgBox confirmation) — that UI confirmation
/// dialog is not included here since it's a UI concern, not solver logic.
/// ---------------------------------------------------------------------