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
    'sizingCostPerKg': TextEditingController(), // populated via lookup, read-only
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

  @override
  void initState() {
    super.initState();
    for (final entry in _controllers.entries) {
      if (entry.key == 'sizingCostPerKg') continue;

      if (entry.key == 'inputInflow') {
        entry.value.addListener(() => _recalculate(solveFrom: SolverMode.inFlow));
      } else if (entry.key == 'targetPrice') {
        entry.value.addListener(() => _recalculate(solveFrom: SolverMode.targetPrice));
      } else {
        entry.value.addListener(() => _recalculate());
      }
    }
  }

  @override
  void dispose() {
    for (final entry in _controllers.entries) {
      entry.value.dispose();
    }
    super.dispose();
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
  void _recalculate({SolverMode? solveFrom}) {
    if (_isSolving) return; // re-entrancy guard, see field doc above

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

      if (rate == null) {
        _greyFabricRate = 0;
        _loomInFlow = 0;
        _solverError = null;
        _controllers['sizingCostPerKg']!.text = '—';
        Future.microtask(() => context.read<CostingProvider>().clear());
        return;
      }
      _controllers['sizingCostPerKg']!.text = rate.perKg.toStringAsFixed(2);

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
        sizingCostPerKg: rate.perKg,
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
          sizingCostPerKg: rate.perKg,
          inputInflow: values['inputInflow']!,
        )
            : ReverseSolver.solveForTargetPrice(
          input: probeInput,
          sizingCostPerKg: rate.perKg,
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
      final output = CalculationEngine.calculate(input: input, sizingCostPerKg: rate.perKg);

      _greyFabricRate = output.greyFabricRate;
      _loomInFlow = output.loomInFlow;

      Future.microtask(() => context.read<CostingProvider>().update(output));
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
                      _field('inputInflow', 'Input Inflow'),
                      _field('targetPrice', 'Target Price'),
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
                      _field('sizingCostPerKg', 'Sizing Cost / Kg', readOnly: true),
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
      ),
    );
  }
}