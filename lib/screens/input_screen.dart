/// input_screen.dart
/// -----------------------------------------------------------------------
/// Main input screen — all Section A fields (Additional Yarn block is
/// intentionally left out of this screen; if it's added back later, give
/// it its own collapsible section instead of mixing it into the main grid).
///
/// Layout: 2-column grid via Wrap, grouped into labeled sections, all
/// labels in Title Case. Ply and Warp Blend sit side-by-side in one row.
/// Input Inflow and Target Price sit immediately after the headline card.
/// Voice input: ONE floating mic button (bottom-right) — no per-field
/// mic icons. Tapping it should open the voice modal (Phase 6, Rabia) —
/// for now it calls _startVoiceInput() which is a stub, see TODO below.
/// Theme: changed only via the side drawer (hamburger icon, top-left) —
/// see widgets/settings_drawer.dart.
///
/// NOTE: perPickRate has been removed entirely (confirmed unused by any
/// formula — it duplicated inputPerPick, which IS used).
///
/// REVERSE-SOLVE BEHAVIOR (Input Inflow / Target Price):
/// These two fields don't feed any forward formula directly (confirmed —
/// neither appears in calculation_engine.dart). In the original Excel
/// workbook they instead drove two VBA macros that solved BACKWARDS for
/// Input Per Pick so that Loom In Flow (for Input Inflow) or Grey Fabric
/// Rate (for Target Price) would match what the user typed. See
/// calculations/reverse_solver.dart for the ported macro logic.
///
/// Here, that's wired automatically: changing Input Inflow or Target
/// Price solves for Input Per Pick and writes it into that field, then
/// runs the normal forward recalculation. Whichever of the two fields
/// was typed into MOST RECENTLY is the "active mode" — the other field
/// is left alone (not auto-updated) until the user types into it
/// directly, matching the Excel macro's single-mode-at-a-time behavior
/// but without the confirmation popup (this is a live form, not a
/// button click, so a dialog on every keystroke would be unusable).
///
/// Input Per Pick itself stays a normal EDITABLE field (per direct
/// instruction) — the user can type into it directly at any time, which
/// simply runs the normal forward pass with whatever they typed (same as
/// before reverse-solving existed). If the user then edits Input Inflow
/// or Target Price again afterward, the solver overwrites Input Per
/// Pick again — this is expected, not a bug.
///
/// LOOP SAFETY: solving writes into inputPerPick's controller, which has
/// its own listener -> _recalculate(). This does NOT re-trigger a solve,
/// because inputPerPick only feeds the FORWARD formula
/// (calculation_engine.dart), not the reverse solver. Only the inflow/
/// targetPrice listeners call the solver, so there is no cycle.
///
/// STEP 17 — TAP TO RELOAD:
/// didChangeDependencies() fires whenever Provider's InheritedWidget
/// rebuilds — including the moment CostingProvider.requestReload() calls
/// notifyListeners() from HistoryScreen. It reads pendingReload; if
/// non-null, it consumes it immediately (so a later rebuild can't apply
/// the same entry twice) and fills every controller via
/// _fillControllersFrom(). That fill relies on each controller's own
/// listener to trigger _recalculate() as values are set — no separate
/// guard or explicit recalculate call is needed, since the LAST field
/// set in the loop will be the one whose listener fires last and runs
/// the calculation with every other field already in place.
///
/// FOCUS-TRIGGERED REVERSE SOLVE (Input Inflow / Target Price):
/// Beyond the text-change listener, both fields also carry a FocusNode
/// that re-runs their reverse solve the instant the field gains focus
/// (tap-in), using whatever number is already there. This fixes a
/// specific staleness bug: solving from Target Price overwrites Input
/// Per Pick, which means Input Inflow's last-displayed number no longer
/// reverse-solves to the CURRENT Input Per Pick — tapping back into
/// Input Inflow without retyping anything used to leave that stale
/// number on screen. See the _inputInflowFocus / _targetPriceFocus
/// field comments below for the full explanation.
///
/// SIZING COST / KG — editable + independent fast lookup:
/// This field is no longer read-only. Warp Count and Ply (plus the Warp
/// Blend dropdown) each trigger _maybeUpdateSizingCost(), a lookup that
/// runs independently of _recalculate() and therefore doesn't wait for
/// all 25+ other fields to be filled in first. Auto-lookup always wins
/// over manual entry the moment those three inputs produce a match;
/// a manually typed value only survives when the repository has no
/// match for the current Warp Count/Ply/Blend combination — see
/// _maybeUpdateSizingCost() and the rate-fallback logic inside
/// _recalculate() for the exact rules.
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
import 'main_nav_shell.dart';

const List<String> kWarpBlendOptions = ['Ctn', 'Pc', 'Pv', 'Pp', 'Cvc', 'Viscose'];

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {
    'ply': TextEditingController(),
    'warpCount': TextEditingController(),
    'weftCount': TextEditingController(),
    'endsPerInch': TextEditingController(),
    'picksPerInch': TextEditingController(),
    'width': TextEditingController(),
    'weave': TextEditingController(),
    'selvedge': TextEditingController(),
    'writing': TextEditingController(),
    'warpShrinkagePct': TextEditingController(),
    'weftShrinkagePct': TextEditingController(),
    'warpWastagePct': TextEditingController(),
    'weftWastagePct': TextEditingController(),
    'warpYarnRate': TextEditingController(),
    'weftYarnRate': TextEditingController(),
    'sizingCostPerKg': TextEditingController(), // auto-filled via lookup, but editable — see _maybeUpdateSizingCost()
    'commissionPct': TextEditingController(),
    'inputPerPick': TextEditingController(),
    'packingCost': TextEditingController(text: '0'),
    'freightCost': TextEditingController(text: '0'),
    'offGradePct': TextEditingController(),
    'offGradeRecovery': TextEditingController(),
    'loomRpm': TextEditingController(),
    'loomEfficiencyPct': TextEditingController(),
    'pickInsertion': TextEditingController(),
    'widthsPerLoom': TextEditingController(),
    'numberOfLooms': TextEditingController(),
    'totalOrder': TextEditingController(),
    'inputInflow': TextEditingController(),
    'targetPrice': TextEditingController(),
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

  // Same idea as _isSolving, but for sizingCostPerKg: when
  // _recalculate() itself writes the looked-up rate into that field
  // (auto-lookup winning over manual entry), that write fires the
  // field's own listener too. Without this guard, that would trigger a
  // second, redundant _recalculate() call right after the first one —
  // harmless in terms of correctness (it would just recompute the same
  // result), but unnecessary work on every keystroke in warpCount/ply.
  bool _isWritingSizingCost = false;

  // FOCUS-TRIGGERED REVERSE SOLVE — Input Inflow / Target Price.
  //
  // Problem this solves: tap Loom In Flow, type a number -> solves
  // Input Per Pick from THAT field. Tap Target Price, type a number ->
  // solves Input Per Pick from Target Price instead, overwriting the
  // previous solve. Tap back into Loom In Flow WITHOUT changing its
  // text -> nothing happens, because the text-change listener only
  // fires on an actual edit. But the number sitting in Loom In Flow is
  // now stale: it no longer matches the Input Per Pick that Target
  // Price's solve just produced. The field looks unchanged, but its
  // "meaning" (whether it still correctly reverse-solves to the CURRENT
  // Input Per Pick) has silently gone wrong — annoying exactly because
  // nothing on screen signals it.
  //
  // Fix: a FocusNode per field, with a listener that fires the SAME
  // reverse solve the moment the field gains focus (tap-in), using
  // whatever number is already sitting in the field. This refreshes
  // the calculation to be consistent with the current Input Per Pick
  // even when the user hasn't typed anything yet — tapping alone is
  // enough to ask "does this field's solve still hold?" and correct it
  // if not.
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

      // SIZING COST / KG — fast, independent lookup.
      //
      // Problem this solves: previously, Sizing Cost / Kg only ever got
      // filled in deep inside _recalculate(), which first checks ALL 25
      // required fields and bails out early if even one is missing. So
      // the user had to fill in the entire form before Sizing Cost / Kg
      // ever appeared — even though the lookup itself only needs 3
      // values (Warp Count, Ply, Warp Blend).
      //
      // Fix: warpCount and ply each also get this lightweight listener,
      // which runs SizingRatesRepository.lookup() on its own the moment
      // all three of its inputs are present — independent of whether
      // the other 22 fields are filled in yet. Warp Blend's dropdown
      // calls this directly from onChanged (see _warpBlendAndPlyRow())
      // since it isn't a text controller.
      //
      // Per direct instruction, auto-lookup ALWAYS overwrites whatever
      // is currently in the field — including a value the user typed
      // in manually. Manual entry only "sticks" when the lookup itself
      // doesn't have a match (incomplete fields, or no matching Sizing
      // Rate row) — at that point _maybeUpdateSizingCost() simply does
      // nothing, leaving whatever's already in the field untouched.
      if (entry.key == 'warpCount' || entry.key == 'ply') {
        entry.value.addListener(_maybeUpdateSizingCost);
      }
    }

    // Re-run the relevant reverse solve as soon as the user taps into
    // either field — see the comment above this block for why a
    // text-change listener alone isn't enough.
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

  /// Looks up Sizing Cost / Kg from just Warp Count + Ply + Warp Blend,
  /// independent of every other field on the form — see the comment in
  /// initState() above for why this exists separately from
  /// _recalculate(). Called from warpCount/ply text listeners and from
  /// the Warp Blend dropdown's onChanged.
  ///
  /// If all three inputs are present and a matching Sizing Rate exists,
  /// the field is overwritten with the looked-up rate (auto-lookup
  /// always wins over manual entry, per direct instruction). If any
  /// input is missing or there's no match, this does nothing — it does
  /// NOT clear the field, so a manually-typed value stays put until a
  /// real match overwrites it.
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
    super.dispose();
  }

  /// Watches CostingProvider for a pending reload request (set when the
  /// user taps a History card). Fills all controllers from the stored
  /// InputModel, then calls consumeReload() to clear the pending state.
  ///
  /// IMPORTANT — must use context.watch() here, not context.read().
  /// InputScreen lives inside MainNavShell's IndexedStack, which keeps
  /// it alive (never disposed/recreated) when switching tabs — that's
  /// the whole point of IndexedStack, so the 28 controllers don't reset
  /// every time the user looks at another tab. But it means
  /// didChangeDependencies() does NOT get a fresh natural trigger just
  /// from switching back to the Costing tab; it only re-runs when an
  /// InheritedWidget this widget actually DEPENDS ON changes. read()
  /// grabs a value once without subscribing, so the widget never
  /// becomes a dependent of CostingProvider, and requestReload()'s
  /// notifyListeners() call goes unnoticed. watch() subscribes properly,
  /// so this method re-fires the moment HistoryScreen calls
  /// requestReload() — which is also why the History tab doesn't need
  /// to be visited for the reload to take effect.
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
  }

  void _startVoiceInput() {
    // TODO (Phase 6): open the voice modal — mic button, live transcript,
    // skip/confirm — and fill _controllers (and _warpBlend) in field
    // order as the user speaks. See project manual Section 5.3 / Phase 6.
  }

  /// [solveFrom] is non-null when this call was triggered by editing
  /// Input Inflow or Target Price — in that case, Input Per Pick is
  /// solved backwards FIRST, then the normal forward pass runs using
  /// the solved value.
  ///
  /// [fromFocus] is true when this call came from a FocusNode listener
  /// (tapping into the field) rather than a text-change listener. In
  /// that case, if the field is empty/zero — i.e. the user hasn't
  /// actually entered a target value yet — skip the solve entirely
  /// instead of showing a "Target Price is zero!" style error just for
  /// tapping into an untouched field.
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
        'widthsPerLoom', 'numberOfLooms', 'totalOrder', 'inputInflow', 'targetPrice',
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

      // SIZING COST / KG — auto-lookup vs manual entry.
      //
      // If the repository has a match (rate != null), it ALWAYS wins —
      // per direct instruction, auto-lookup overwrites any manually
      // typed value the moment Warp Count/Ply/Blend changes. The field
      // itself is updated to show the looked-up number, replacing
      // whatever was there before.
      //
      // If there's no match (rate == null) — which the repository's
      // closest-match logic makes rare, but not impossible — fall back
      // to whatever is currently sitting in the Sizing Cost / Kg field,
      // since that may be a value the user typed in deliberately. Only
      // bail out to the zeroed/cleared state if that field is ALSO
      // empty or invalid, i.e. there is truly no usable rate from
      // either source.
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
        // Leave the field exactly as the user typed it — don't reformat
        // or touch it here.
      }

      // Build the InputModel with whatever Input Per Pick currently is —
      // needed both as the final forward-pass input AND, if solveFrom is
      // set, as the "fixed values" source the solver reads from (the
      // solver only reads fields that don't depend on inputPerPick, so
      // its current value here is irrelevant to the solve itself).
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
        inputInflow: values['inputInflow']!,
        targetPrice: values['targetPrice']!,
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
          // Don't touch inputPerPick or the headline numbers — leave the
          // last good state on screen rather than zeroing everything out
          // over a transient invalid value (e.g. while the user is still
          // typing "Target Price too low" mid-keystroke).
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
    // Trim trailing zeros so the field doesn't show "0.691512000" —
    // matches how a person would type it in.
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
                'ST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('SadeedTex', style: TextStyle(fontSize: 16)),
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
                    // Input Inflow + Target Price come right after the
                    // headline card. Editing either one re-solves Input
                    // Per Pick automatically — see the class-level doc
                    // comment for how the two stay in sync without
                    // looping.
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
                    _section('Shrinkage & Wastage', [
                      _field('warpShrinkagePct', 'Warp Shrinkage %'),
                      _field('weftShrinkagePct', 'Weft Shrinkage %'),
                      _field('warpWastagePct', 'Warp Wastage %'),
                      _field('weftWastagePct', 'Weft Wastage %'),
                    ]),
                    _section('Rates & Costing', [
                      _field('warpYarnRate', 'Warp Yarn Rate'),
                      _field('weftYarnRate', 'Weft Yarn Rate'),
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
                      _warpBlend = value;
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