/// input_screen.dart
/// -----------------------------------------------------------------------
/// Main input screen — all Section A fields (Additional Yarn block is
/// intentionally left out of this screen; if it's added back later, give
/// it its own collapsible section instead of mixing it into the main grid).
///
/// Layout: 2-column grid via Wrap, grouped into labeled sections, all
/// labels in Title Case. Ply and Warp Blend sit side-by-side in one row.
/// Input Inflow and Target Price sit immediately after the headline card.
///
/// VOICE INPUT (Step 19 — now wired up): see voice_input_modal.dart.
/// Warp Blend is handled via warpBlendValue/onWarpBlendChanged (it's a
/// plain `_warpBlend` field backing a DropdownButton, not a
/// TextEditingController) — see VoiceInputModal's own class doc comment
/// for the full story of why that distinction matters.
///
/// NOTE: perPickRate has been removed entirely (confirmed unused by any
/// formula — it duplicated inputPerPick, which IS used).
///
/// REVERSE-SOLVE BEHAVIOR (Input Inflow / Target Price): see
/// calculations/reverse_solver.dart.
///
/// STEP 20 — YARN RATE UNIT TOGGLE (per lb / per 10lb):
/// The Sizing/costing formula (calculation_engine.dart) has always
/// divided warpYarnRate/weftYarnRate by 10 before multiplying by weight
/// — i.e. InputModel.warpYarnRate and weftYarnRate are ALWAYS the
/// "per 10 lb" figure, and that has not changed. What's new is that the
/// customer sometimes wants to type the rate as a straight "per lb"
/// price instead of mentally multiplying by 10 first.
///
/// This is handled ENTIRELY as a display/entry convenience in this
/// screen — InputModel, calculation_engine.dart, and reverse_solver.dart
/// are completely unchanged and never see anything except the resolved
/// per-10lb number, exactly as before.
///
/// Mechanism: _warpYarnRateUnit / _weftYarnRateUnit track which unit the
/// person is currently entering in (default: perTenLb, matching the
/// previous behavior exactly). The TextField for each rate always shows
/// whatever the person actually typed, in whichever unit is selected —
/// it is NEVER silently rewritten to a converted number, since that
/// would be confusing (type "12", watch it jump to "120"). Conversion
/// only happens at the point those fields are READ for calculation —
/// see _resolvedWarpYarnRate()/_resolvedWeftYarnRate(), which are used
/// everywhere _recalculate() and the reverse solver previously read
/// _controllers['warpYarnRate']/['weftYarnRate'] directly. When the
/// person flips the toggle, the displayed number is converted ONCE (so
/// switching units doesn't change the underlying real-world rate they
/// meant), then stays in that new unit for further typing.
///
/// STEP 20 — SHRINKAGE FROM WEIGHT (alternate entry mode):
/// The customer normally provides Warp/Weft Shrinkage % and Warp/Weft
/// Wastage % directly (the original, still-default behavior — nothing
/// about that path changes). The new alternate mode lets them instead
/// provide a single WEIGHT figure for warp and weft, with Wastage fixed
/// at 3% for both (per direct instruction), and Shrinkage % is reverse-
/// derived from that weight using the exact same formula
/// calculation_engine.dart already uses forward:
///   WarpWeight = ROUND(EndsPerInch * Width * (1 + WarpShrinkage/100 +
///                 WarpWastage/100) / (768.1 * WarpCount) /
///                 (1 - OffGrade/100), 4)
/// Solved for WarpShrinkage (with WarpWastage fixed at 3):
///   WarpShrinkage% = ((WarpWeight * 768.1 * WarpCount *
///                      (1 - OffGrade/100)) / (EndsPerInch * Width)
///                      - 1.03) * 100
/// (WeftShrinkage mirrors this using PicksPerInch/WeftCount/WeftWeight.)
///
/// Toggling this mode ON:
///   - Wastage% fields are forced to '3' and made read-only.
///   - Shrinkage% fields become read-only and are filled by the reverse
///     formula above, recomputed live whenever Warp/Weft Weight,
///     EndsPerInch/PicksPerInch, Width, WarpCount/WeftCount, or Off
///     Grade % change.
///   - If the inputs would imply a NEGATIVE shrinkage (weight entered is
///     too small for the other geometry to be physically consistent),
///     the field shows an inline error instead of writing a negative
///     percent — calculation_engine.dart is never handed a nonsensical
///     negative shrinkage.
/// Toggling OFF restores normal manual entry for both Shrinkage% and
/// Wastage% (Wastage% is simply unlocked again — it stays at '3' until
/// the person edits it, rather than being reset to some other default).
///
/// Either way, by the time _recalculate() runs, warpShrinkagePct/
/// weftShrinkagePct/warpWastagePct/weftWastagePct controllers hold a
/// normal resolved percent — InputModel and calculation_engine.dart
/// have no idea which entry mode produced that number, exactly like the
/// yarn-rate unit toggle above.
///
/// Theme: changed only via the side drawer (hamburger icon, top-left) —
/// see widgets/settings_drawer.dart.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../calculations/calculation_engine.dart';
import '../calculations/reverse_solver.dart';
import '../models/input_model.dart';
import '../services/sizing_rates_repository.dart';
import '../theme/costing_provider.dart';
import '../widgets/headline_banner.dart';
import '../widgets/input_field_card.dart';
import '../widgets/share_action_button.dart';
import '../widgets/voice_input_modal.dart';
import '../widgets/warp_blend_options.dart';
import 'main_nav_shell.dart';

/// Which unit the person is currently typing a yarn rate in. Purely a
/// UI/entry concern — see the STEP 20 doc comment above. Internally
/// everything still resolves to "per 10 lb" before reaching InputModel.
enum YarnRateUnit { perLb, perTenLb }

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {
    'ply': TextEditingController(text: '1'),
    'warpCount': TextEditingController(),
    'weftCount': TextEditingController(),
    'endsPerInch': TextEditingController(),
    'picksPerInch': TextEditingController(),
    'width': TextEditingController(),
    'weave': TextEditingController(text: '1/1'),
    'selvedge': TextEditingController(text: 'Leno'),
    'writing': TextEditingController(text: 'Non'),
    'warpShrinkagePct': TextEditingController(text: '7'),
    'weftShrinkagePct': TextEditingController(text: '7'),
    'warpWastagePct': TextEditingController(text: '3'),
    'weftWastagePct': TextEditingController(text: '3'),
    'warpYarnRate': TextEditingController(),
    'weftYarnRate': TextEditingController(),
    'sizingCostPerKg': TextEditingController(), // auto-filled via lookup, but editable — see _maybeUpdateSizingCost()
    'commissionPct': TextEditingController(text: '1'),
    'inputPerPick': TextEditingController(),
    'packingCost': TextEditingController(text: '0'),
    'freightCost': TextEditingController(text: '0'),
    'offGradePct': TextEditingController(text: '1'),
    'offGradeRecovery': TextEditingController(text: '50'),
    'loomRpm': TextEditingController(text: '750'),
    'loomEfficiencyPct': TextEditingController(text: '90'),
    'pickInsertion': TextEditingController(text: '1'),
    'widthsPerLoom': TextEditingController(text: '1'),
    'numberOfLooms': TextEditingController(text: '5'),
    'totalOrder': TextEditingController(text: '50000'),
    'inputInflow': TextEditingController(text: '0'),
    'targetPrice': TextEditingController(text: '0'),
  };

  String? _warpBlend;
  double _greyFabricRate = 0;
  double _loomInFlow = 0;
  String? _solverError;

  // Guards against re-entrancy: while a solver-triggered text update is
  // being written into inputPerPick, ignore that controller's own
  // listener firing (it will fire, harmlessly, but skipping it here
  // avoids a redundant double-recalculate).
  bool _isSolving = false;

  // Same idea as _isSolving, but for sizingCostPerKg.
  bool _isWritingSizingCost = false;

  // ---------------------------------------------------------------------
  // STEP 20 — Yarn Rate unit toggle state.
  // Default perTenLb matches the value that was always being typed in
  // here before this feature existed, so existing users/history entries
  // see no behavior change unless they explicitly switch a toggle.
  // ---------------------------------------------------------------------
  YarnRateUnit _warpYarnRateUnit = YarnRateUnit.perTenLb;
  YarnRateUnit _weftYarnRateUnit = YarnRateUnit.perTenLb;

  /// The resolved, ALWAYS-per-10lb number that should actually be fed
  /// into InputModel/calculation_engine.dart/reverse_solver.dart — use
  /// this everywhere _controllers['warpYarnRate']!.text used to be read
  /// directly for a calculation. Returns null if the field is empty or
  /// not a valid number (same contract double.tryParse callers expect).
  double? _resolvedWarpYarnRate() {
    final raw = double.tryParse(_controllers['warpYarnRate']!.text.trim());
    if (raw == null) return null;
    return _warpYarnRateUnit == YarnRateUnit.perLb ? raw * 10 : raw;
  }

  double? _resolvedWeftYarnRate() {
    final raw = double.tryParse(_controllers['weftYarnRate']!.text.trim());
    if (raw == null) return null;
    return _weftYarnRateUnit == YarnRateUnit.perLb ? raw * 10 : raw;
  }

  /// Flips the unit for one of the two rate fields, converting the
  /// CURRENTLY DISPLAYED number so the real-world rate the person meant
  /// stays the same — e.g. "12" per-lb becomes "120" per-10lb, not left
  /// at "12" now meaning something 10x smaller. Only runs the
  /// conversion if the field currently holds a valid number; an empty
  /// or invalid field just switches the unit with nothing to convert.
  void _setWarpYarnRateUnit(YarnRateUnit unit) {
    if (unit == _warpYarnRateUnit) return;
    final controller = _controllers['warpYarnRate']!;
    final current = double.tryParse(controller.text.trim());
    setState(() {
      if (current != null) {
        final converted =
        unit == YarnRateUnit.perLb ? current / 10 : current * 10;
        controller.text = _formatNumber(converted);
      }
      _warpYarnRateUnit = unit;
    });
    _recalculate();
  }

  void _setWeftYarnRateUnit(YarnRateUnit unit) {
    if (unit == _weftYarnRateUnit) return;
    final controller = _controllers['weftYarnRate']!;
    final current = double.tryParse(controller.text.trim());
    setState(() {
      if (current != null) {
        final converted =
        unit == YarnRateUnit.perLb ? current / 10 : current * 10;
        controller.text = _formatNumber(converted);
      }
      _weftYarnRateUnit = unit;
    });
    _recalculate();
  }

  // ---------------------------------------------------------------------
  // STEP 20 — Shrinkage-from-Weight toggle state.
  // ---------------------------------------------------------------------
  bool _useWeightForShrinkage = false;

  // Separate controllers for the weight entry fields — NOT part of
  // _controllers/InputModel; these are pure UI inputs that feed the
  // reverse-shrinkage formula, the same role a calculator's scratch
  // pad would play. Nothing reads these except this screen.
  final TextEditingController _warpWeightController = TextEditingController();
  final TextEditingController _weftWeightController = TextEditingController();

  // Inline error text shown under the weight fields when the entered
  // weight would reverse-solve to a negative shrinkage (physically
  // inconsistent with the other geometry fields) — see
  // _recomputeShrinkageFromWeight() below.
  String? _warpWeightError;
  String? _weftWeightError;

  void _setUseWeightForShrinkage(bool value) {
    setState(() {
      _useWeightForShrinkage = value;
      if (value) {
        // Wastage is fixed at 3/3 in this mode, per direct instruction.
        _controllers['warpWastagePct']!.text = '3';
        _controllers['weftWastagePct']!.text = '3';
        _recomputeShrinkageFromWeight();
      } else {
        // Leaving weight mode: just unlock the fields again. Wastage
        // stays at whatever it currently shows ('3', most likely) until
        // the person edits it by hand — nothing is reset to a different
        // default, since there's no other "previous" value to restore.
        _warpWeightError = null;
        _weftWeightError = null;
      }
    });
    _recalculate();
  }

  /// Reverse-solves Warp/Weft Shrinkage % from the user-entered
  /// Warp/Weft Weight, with Wastage fixed at 3 — see the STEP 20 doc
  /// comment at the top of this file for the algebra. Only writes a
  /// result when every input it needs is present and produces a
  /// non-negative shrinkage; otherwise leaves the field as-is and sets
  /// the matching error string instead (so a half-typed weight doesn't
  /// flash a wrong/negative percent while the person is still typing).
  void _recomputeShrinkageFromWeight() {
    if (!_useWeightForShrinkage) return;

    final endsPerInch = double.tryParse(_controllers['endsPerInch']!.text.trim());
    final picksPerInch = double.tryParse(_controllers['picksPerInch']!.text.trim());
    final width = double.tryParse(_controllers['width']!.text.trim());
    final warpCount = double.tryParse(_controllers['warpCount']!.text.trim());
    final weftCount = double.tryParse(_controllers['weftCount']!.text.trim());
    final offGrade = double.tryParse(_controllers['offGradePct']!.text.trim());
    final warpWeight = double.tryParse(_warpWeightController.text.trim());
    final weftWeight = double.tryParse(_weftWeightController.text.trim());

    setState(() {
      _warpWeightError = null;
      if (warpWeight != null &&
          endsPerInch != null &&
          width != null &&
          warpCount != null &&
          offGrade != null &&
          endsPerInch != 0 &&
          width != 0) {
        final pct = ((warpWeight * 768.1 * warpCount * (1 - offGrade / 100)) /
            (endsPerInch * width) -
            1.03) *
            100;
        if (pct < 0) {
          _warpWeightError = 'Weight too low for these dimensions';
        } else {
          _controllers['warpShrinkagePct']!.text = _formatNumber(pct);
        }
      }

      _weftWeightError = null;
      if (weftWeight != null &&
          picksPerInch != null &&
          width != null &&
          weftCount != null &&
          offGrade != null &&
          picksPerInch != 0 &&
          width != 0) {
        final pct = ((weftWeight * 768.1 * weftCount * (1 - offGrade / 100)) /
            (picksPerInch * width) -
            1.03) *
            100;
        if (pct < 0) {
          _weftWeightError = 'Weight too low for these dimensions';
        } else {
          _controllers['weftShrinkagePct']!.text = _formatNumber(pct);
        }
      }
    });
  }

  // FOCUS-TRIGGERED REVERSE SOLVE — Input Inflow / Target Price.
  final _inputInflowFocus = FocusNode();
  final _targetPriceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    for (final entry in _controllers.entries) {
      if (entry.key == 'inputInflow') {
        entry.value.addListener(() => _recalculate(solveFrom: SolverMode.inFlow));
      } else if (entry.key == 'targetPrice') {
        entry.value.addListener(() => _recalculate(solveFrom: SolverMode.targetPrice));
      } else {
        entry.value.addListener(() => _recalculate());
      }

      if (entry.key == 'warpCount' || entry.key == 'ply') {
        entry.value.addListener(_maybeUpdateSizingCost);
      }

      // STEP 20 — any of the geometry fields the reverse-shrinkage
      // formula depends on should refresh the derived %ages live when
      // weight mode is active. Harmless no-op (early-returns instantly)
      // when _useWeightForShrinkage is false.
      if (entry.key == 'endsPerInch' ||
          entry.key == 'picksPerInch' ||
          entry.key == 'width' ||
          entry.key == 'warpCount' ||
          entry.key == 'weftCount' ||
          entry.key == 'offGradePct') {
        entry.value.addListener(_recomputeShrinkageFromWeight);
      }
    }

    _warpWeightController.addListener(_recomputeShrinkageFromWeight);
    _weftWeightController.addListener(_recomputeShrinkageFromWeight);

    _inputInflowFocus.addListener(() {
      if (_inputInflowFocus.hasFocus) {
        _recalculate(solveFrom: SolverMode.inFlow, fromFocus: true);
      }
    });
    _targetPriceFocus.addListener(() {
      if (_targetPriceFocus.hasFocus) {
        _recalculate(solveFrom: SolverMode.targetPrice, fromFocus: true);
      }
    });
  }

  void _maybeUpdateSizingCost() {
    final warpCount = double.tryParse(_controllers['warpCount']!.text.trim());
    final ply = double.tryParse(_controllers['ply']!.text.trim());
    final warpBlend = _warpBlend;

    if (warpCount == null || ply == null || warpBlend == null || warpBlend.isEmpty) {
      return;
    }

    final rate = SizingRatesRepository.instance.lookup(
      count: warpCount,
      ply: ply,
      blend: warpBlend,
    );

    if (rate == null) return; // no match — leave the field as-is

    _isWritingSizingCost = true;
    setState(() {
      _controllers['sizingCostPerKg']!.text = rate.perKg.toStringAsFixed(2);
    });
    _isWritingSizingCost = false;
  }

  @override
  void dispose() {
    for (final entry in _controllers.entries) {
      entry.value.dispose();
    }
    _inputInflowFocus.dispose();
    _targetPriceFocus.dispose();
    _warpWeightController.dispose();
    _weftWeightController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pending = context.watch<CostingProvider>().pendingReload;
    if (pending == null) return;
    context.read<CostingProvider>().consumeReload();
    _fillControllersFrom(pending);
  }

  /// Fills every controller (and _warpBlend dropdown) from a saved
  /// InputModel — used by "tap to reload" (Step 17).
  ///
  /// STEP 20 note: warpYarnRate/weftYarnRate from a saved InputModel are
  /// always the resolved per-10lb number (that's all InputModel has ever
  /// stored) — reloading always displays them in per-10lb terms too,
  /// resetting both unit toggles back to perTenLb. This is deliberate:
  /// there's no stored record of which unit the person originally typed
  /// in, so per-10lb (the unambiguous, calculation-native unit) is the
  /// only safe default on reload. Same reasoning for shrinkage: a
  /// reloaded entry always shows in normal %-entry mode, since there's
  /// no stored "weight" value to repopulate the weight fields with.
  void _fillControllersFrom(InputModel input) {
    _warpBlend = input.warpBlend;
    _controllers['ply']!.text = input.ply.toString();
    _controllers['warpCount']!.text = input.warpCount.toString();
    _controllers['weftCount']!.text = input.weftCount.toString();
    _controllers['endsPerInch']!.text = input.endsPerInch.toString();
    _controllers['picksPerInch']!.text = input.picksPerInch.toString();
    _controllers['width']!.text = input.width.toString();
    _controllers['weave']!.text = input.weave;
    _controllers['selvedge']!.text = input.selvedge;
    _controllers['writing']!.text = input.writing;
    _controllers['warpShrinkagePct']!.text = input.warpShrinkagePct.toString();
    _controllers['weftShrinkagePct']!.text = input.weftShrinkagePct.toString();
    _controllers['warpWastagePct']!.text = input.warpWastagePct.toString();
    _controllers['weftWastagePct']!.text = input.weftWastagePct.toString();
    _controllers['warpYarnRate']!.text = input.warpYarnRate.toString();
    _controllers['weftYarnRate']!.text = input.weftYarnRate.toString();
    _controllers['commissionPct']!.text = input.commissionPct.toString();
    _controllers['inputPerPick']!.text = input.inputPerPick.toString();
    _controllers['packingCost']!.text = input.packingCost.toString();
    _controllers['freightCost']!.text = input.freightCost.toString();
    _controllers['offGradePct']!.text = input.offGradePct.toString();
    _controllers['offGradeRecovery']!.text = input.offGradeRecovery.toString();
    _controllers['loomRpm']!.text = input.loomRpm.toString();
    _controllers['loomEfficiencyPct']!.text = input.loomEfficiencyPct.toString();
    _controllers['pickInsertion']!.text = input.pickInsertion.toString();
    _controllers['widthsPerLoom']!.text = input.widthsPerLoom.toString();
    _controllers['numberOfLooms']!.text = input.numberOfLooms.toString();
    _controllers['totalOrder']!.text = input.totalOrder.toString();
    _controllers['inputInflow']!.text = input.inputInflow.toString();
    _controllers['targetPrice']!.text = input.targetPrice.toString();
    // sizingCostPerKg is read-only (lookup result), don't fill it —
    // it will auto-update when _recalculate() runs from the listeners.

    // STEP 20 — reset both entry-mode toggles to their defaults on
    // reload, per the doc comment above.
    _warpYarnRateUnit = YarnRateUnit.perTenLb;
    _weftYarnRateUnit = YarnRateUnit.perTenLb;
    _useWeightForShrinkage = false;
    _warpWeightController.clear();
    _weftWeightController.clear();
    _warpWeightError = null;
    _weftWeightError = null;
  }

  /// STEP 19 — opens the voice-fill modal as a bottom sheet.
  Future<void> _startVoiceInput() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => VoiceInputModal(
        controllers: _controllers,
        warpBlendValue: _warpBlend,
        onWarpBlendChanged: (value) {
          setState(() {
            _warpBlend = value;
          });
          _maybeUpdateSizingCost();
          _recalculate();
        },
      ),
    );
    if (!mounted) return;
    _maybeUpdateSizingCost();
    _recalculate();
  }

  void _recalculate({SolverMode? solveFrom, bool fromFocus = false}) {
    if (_isSolving) return; // re-entrancy guard, see field doc above
    if (_isWritingSizingCost) return; // see field doc above

    if (fromFocus && solveFrom != null) {
      final key = solveFrom == SolverMode.inFlow ? 'inputInflow' : 'targetPrice';
      final current = double.tryParse(_controllers[key]!.text.trim());
      if (current == null || current == 0) return;
    }

    setState(() {
      double? num(String key) => double.tryParse(_controllers[key]!.text.trim());

      final values = {
        for (final key in _controllers.keys) key: num(key),
      };

      // STEP 20 — warpYarnRate/weftYarnRate are overridden here with the
      // UNIT-RESOLVED values (always per-10lb) instead of the raw parsed
      // controller text, which may be in per-lb terms right now. Every
      // other read of `values` below is unaffected — this is the single
      // point where the unit conversion actually takes effect for the
      // forward calculation.
      values['warpYarnRate'] = _resolvedWarpYarnRate();
      values['weftYarnRate'] = _resolvedWeftYarnRate();

      final warpBlend = _warpBlend ?? '';
      final weave = _controllers['weave']!.text.trim();
      final selvedge = _controllers['selvedge']!.text.trim();
      final writing = _controllers['writing']!.text.trim();

      const requiredNumericKeys = [
        'ply', 'warpCount', 'weftCount', 'endsPerInch', 'picksPerInch', 'width',
        'warpShrinkagePct', 'weftShrinkagePct', 'warpWastagePct', 'weftWastagePct',
        'warpYarnRate', 'weftYarnRate', 'commissionPct', 'inputPerPick',
        'packingCost', 'freightCost', 'offGradePct',
        'offGradeRecovery', 'loomRpm', 'loomEfficiencyPct', 'pickInsertion',
        'widthsPerLoom', 'numberOfLooms', 'totalOrder'
      ];
      final missing = requiredNumericKeys.where((k) => values[k] == null).toList();
      if (warpBlend.isEmpty || weave.isEmpty || missing.isNotEmpty) {
        _greyFabricRate = 0;
        _loomInFlow = 0;
        _solverError = null;
        Future.microtask(() => context.read<CostingProvider>().clear());
        return;
      }

      final rate = SizingRatesRepository.instance.lookup(
        count: values['warpCount']!,
        ply: values['ply']!,
        blend: warpBlend,
      );

      double effectiveSizingCost;
      if (rate != null) {
        effectiveSizingCost = rate.perKg;
        _isWritingSizingCost = true;
        _controllers['sizingCostPerKg']!.text = rate.perKg.toStringAsFixed(2);
        _isWritingSizingCost = false;
      } else {
        final manual = double.tryParse(_controllers['sizingCostPerKg']!.text.trim());
        if (manual == null) {
          _greyFabricRate = 0;
          _loomInFlow = 0;
          _solverError = null;
          Future.microtask(() => context.read<CostingProvider>().clear());
          return;
        }
        effectiveSizingCost = manual;
      }

      InputModel buildInput(double inputPerPickValue) => InputModel(
        warpBlend: warpBlend,
        ply: values['ply']!,
        warpCount: values['warpCount']!,
        weftCount: values['weftCount']!,
        endsPerInch: values['endsPerInch']!,
        picksPerInch: values['picksPerInch']!,
        width: values['width']!,
        weave: weave,
        selvedge: selvedge,
        writing: writing,
        warpShrinkagePct: values['warpShrinkagePct']!,
        weftShrinkagePct: values['weftShrinkagePct']!,
        warpWastagePct: values['warpWastagePct']!,
        weftWastagePct: values['weftWastagePct']!,
        warpYarnRate: values['warpYarnRate']!,
        weftYarnRate: values['weftYarnRate']!,
        sizingCostPerKg: effectiveSizingCost,
        commissionPct: values['commissionPct']!,
        offGradePct: values['offGradePct']!,
        offGradeRecovery: values['offGradeRecovery']!,
        loomRpm: values['loomRpm']!,
        loomEfficiencyPct: values['loomEfficiencyPct']!,
        pickInsertion: values['pickInsertion']!,
        widthsPerLoom: values['widthsPerLoom']!,
        numberOfLooms: values['numberOfLooms']!,
        totalOrder: values['totalOrder']!,
        inputInflow: values['inputInflow'] ?? 0,
        targetPrice: values['targetPrice'] ?? 0,
        packingCost: values['packingCost']!,
        freightCost: values['freightCost']!,
        inputPerPick: inputPerPickValue,
      );

      var inputPerPick = values['inputPerPick']!;

      if (solveFrom != null) {
        final probeInput = buildInput(inputPerPick);
        final result = solveFrom == SolverMode.inFlow
            ? ReverseSolver.solveForInFlow(
          input: probeInput,
          sizingCostPerKg: effectiveSizingCost,
          inputInflow: values['inputInflow']!,
        )
            : ReverseSolver.solveForTargetPrice(
          input: probeInput,
          sizingCostPerKg: effectiveSizingCost,
          targetPrice: values['targetPrice']!,
        );

        if (result.isError) {
          _solverError = result.errorMessage;
          return;
        }

        _solverError = null;
        inputPerPick = result.inputPerPick!;
        _isSolving = true;
        _controllers['inputPerPick']!.text = _formatNumber(inputPerPick);
        _isSolving = false;
      } else {
        _solverError = null;
      }

      final input = buildInput(inputPerPick);
      final output = CalculationEngine.calculate(input: input, sizingCostPerKg: effectiveSizingCost);

      _greyFabricRate = output.greyFabricRate;
      _loomInFlow = output.loomInFlow;

      Future.microtask(() => context.read<CostingProvider>().update(input, output));
    });
  }

  String _formatNumber(double value) {
    var s = value.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open Menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                'TT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            const Text('TrendTex', style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: const [ShareActionButton()],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeadlineBanner(
                greyFabricRate: _greyFabricRate,
                loomInFlow: _loomInFlow,
              ),
              if (_solverError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _solverError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Inflow & Target', [
                      _field('inputInflow', 'Input Inflow', focusNode: _inputInflowFocus),
                      _field('targetPrice', 'Target Price', focusNode: _targetPriceFocus),
                    ]),
                    _section('Fabric Specification', [
                      _warpBlendAndPlyRow(),
                      _field('warpCount', 'Warp Count (Ne)'),
                      _field('weftCount', 'Weft Count (Ne)'),
                      _field('endsPerInch', 'Ends Per Inch'),
                      _field('picksPerInch', 'Picks Per Inch'),
                      _field('width', 'Width'),
                      _field('weave', 'Weave', type: FieldType.text),
                      _field('selvedge', 'Selvedge', type: FieldType.text),
                      _field('writing', 'Writing', type: FieldType.text),
                    ]),
                    _shrinkageWastageSection(),
                    _section('Rates & Costing', [
                      _yarnRateField(
                        key: 'warpYarnRate',
                        label: 'Warp Yarn Rate',
                        unit: _warpYarnRateUnit,
                        onUnitChanged: _setWarpYarnRateUnit,
                      ),
                      _yarnRateField(
                        key: 'weftYarnRate',
                        label: 'Weft Yarn Rate',
                        unit: _weftYarnRateUnit,
                        onUnitChanged: _setWeftYarnRateUnit,
                      ),
                      _field('sizingCostPerKg', 'Sizing Cost / Kg'),
                      _field('commissionPct', 'Commission %'),
                      _field('inputPerPick', 'Input Per Pick'),
                      _field('packingCost', 'Packing Cost'),
                      _field('freightCost', 'Freight Cost'),
                    ]),
                    _section('Off Grade', [
                      _field('offGradePct', 'Off Grade %'),
                      _field('offGradeRecovery', 'Off Grade Recovery'),
                    ]),
                    _section('Loom & Production', [
                      _field('loomRpm', 'Loom RPM'),
                      _field('loomEfficiencyPct', 'Loom Efficiency %'),
                      _field('pickInsertion', 'Pick Insertion'),
                      _field('widthsPerLoom', 'Widths / Loom'),
                      _field('numberOfLooms', 'No. Of Looms'),
                      _field('totalOrder', 'Total Order'),
                    ]),
                    const SizedBox(height: 90), // clearance for the FAB
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startVoiceInput,
        tooltip: 'Fill Fields With Voice',
        child: const Icon(Icons.mic),
      ),
    );
  }

  Widget _section(String title, List<Widget> fields) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: fields,
          ),
        ],
      ),
    );
  }

  /// STEP 20 — Shrinkage & Wastage section, now with a mode toggle.
  /// When _useWeightForShrinkage is false, this renders EXACTLY like
  /// before (four plain editable % fields). When true, it instead shows
  /// the two weight-entry fields plus the same four % fields rendered
  /// read-only (Wastage pinned at 3, Shrinkage filled by the reverse
  /// formula).
  Widget _shrinkageWastageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32;
    final halfWidth = (usableWidth - 8) / 2;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SHRINKAGE & WASTAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Use weight instead',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  Switch(
                    value: _useWeightForShrinkage,
                    onChanged: _setUseWeightForShrinkage,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_useWeightForShrinkage) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: halfWidth,
                  child: InputFieldCard(
                    label: 'Warp Weight',
                    controller: _warpWeightController,
                    type: FieldType.number
                  ),
                ),
                SizedBox(
                  width: halfWidth,
                  child: InputFieldCard(
                    label: 'Weft Weight',
                    controller: _weftWeightController,
                    type: FieldType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _field(
                'warpShrinkagePct',
                'Warp Shrinkage %',
                readOnly: _useWeightForShrinkage,
              ),
              _field(
                'weftShrinkagePct',
                'Weft Shrinkage %',
                readOnly: _useWeightForShrinkage,
              ),
              _field(
                'warpWastagePct',
                'Warp Wastage %',
                readOnly: _useWeightForShrinkage,
              ),
              _field(
                'weftWastagePct',
                'Weft Wastage %',
                readOnly: _useWeightForShrinkage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _warpBlendAndPlyRow() {
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32;
    final halfWidth = (usableWidth - 8) / 2;
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: halfWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Warp Blend',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _warpBlend,
                    isDense: true,
                    isExpanded: true,
                    hint: Text(
                      'Select',
                      style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    items: kWarpBlendOptions
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _warpBlend = value);
                      _maybeUpdateSizingCost();
                      _recalculate();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: halfWidth,
          child: InputFieldCard(
            label: 'Ply',
            controller: _controllers['ply']!,
            type: FieldType.number,
          ),
        ),
      ],
    );
  }

  /// STEP 20 — Warp/Weft Yarn Rate field with its per-lb / per-10lb
  /// toggle. The underlying TextField is the SAME _controllers entry as
  /// before (unchanged key, unchanged width/layout) — only a small unit
  /// switcher is added above it. See _resolvedWarpYarnRate()/
  /// _resolvedWeftYarnRate() for where the actual conversion happens;
  /// nothing here touches the displayed text based on the unit, only on
  /// an explicit toggle action (_setWarpYarnRateUnit/
  /// _setWeftYarnRateUnit).
  Widget _yarnRateField({
    required String key,
    required String label,
    required YarnRateUnit unit,
    required ValueChanged<YarnRateUnit> onUnitChanged,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32;
    final halfWidth = (usableWidth - 8) / 2;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: halfWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputFieldCard(
            label: label,
            controller: _controllers[key]!,
            type: FieldType.number,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _unitChip(
                label: 'per lb',
                selected: unit == YarnRateUnit.perLb,
                onTap: () => onUnitChanged(YarnRateUnit.perLb),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 6),
              _unitChip(
                label: 'per 10 lb',
                selected: unit == YarnRateUnit.perTenLb,
                onTap: () => onUnitChanged(YarnRateUnit.perTenLb),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _unitChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _field(
      String key,
      String label, {
        FieldType type = FieldType.number,
        bool fullWidth = false,
        bool readOnly = false,
        FocusNode? focusNode,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32;
    final halfWidth = (usableWidth - 8) / 2;

    return SizedBox(
      width: fullWidth ? usableWidth : halfWidth,
      child: InputFieldCard(
        label: label,
        controller: _controllers[key]!,
        type: type,
        fullWidth: fullWidth,
        readOnly: readOnly,
        focusNode: focusNode,
      ),
    );
  }
}