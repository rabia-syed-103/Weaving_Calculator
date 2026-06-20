/// input_screen.dart
/// -----------------------------------------------------------------------
/// Main input screen — all 31 Section A fields (Additional Yarn block is
/// intentionally left out of this screen per latest direction; if it's
/// added back later, give it its own collapsible section instead of
/// mixing it into the main grid).
///
/// Layout: 2-column grid via Wrap, grouped into labeled sections.
/// Voice input: ONE floating mic button (bottom-right) — no per-field
/// mic icons. Tapping it should open the voice modal (Phase 6, Rabia) —
/// for now it calls _startVoiceInput() which is a stub, see TODO below.
/// Theme: changed only via the side drawer (hamburger icon, top-left) —
/// see widgets/settings_drawer.dart.
library;

import 'package:flutter/material.dart';
import '../calculations/calculation_engine.dart';
import '../models/input_model.dart';
import '../theme/costing_provider.dart';
import 'package:provider/provider.dart';
import '../services/sizing_rates_repository.dart';
import '../widgets/headline_banner.dart';
import 'main_nav_shell.dart';
import '../widgets/input_field_card.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();

  // One controller per field. Grouped in a map so the voice-input parser
  // (Phase 6) can fill them in sequence by key without needing 31
  // separate named variables.
  final Map<String, TextEditingController> _controllers = {
    'warpBlend': TextEditingController(),
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
    'perPickRate': TextEditingController(),
    'packingCost': TextEditingController(),
    'freightCost': TextEditingController(),
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

  // Placeholder headline values until wired to CalculationEngine in
  // Phase 4. Replace with state driven by the live OutputModel.
  double _greyFabricRate = 0;
  double _loomInFlow = 0;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _startVoiceInput() {
    // TODO (Phase 6): open the voice modal — mic button, live transcript,
    // skip/confirm — and fill _controllers in field order as the user
    // speaks. See project manual Section 5.3 / Phase 6 tasks.
  }

  void _recalculate() {
    double? num(String key) => double.tryParse(_controllers[key]!.text.trim());

    final values = {
      for (final key in _controllers.keys) key: num(key),
    };

    final warpBlend = _controllers["warpBlend"]!.text.trim();
    final weave = _controllers["weave"]!.text.trim();
    final selvedge = _controllers["selvedge"]!.text.trim();
    final writing = _controllers["writing"]!.text.trim();

    const requiredNumericKeys = [
      "ply", "warpCount", "weftCount", "endsPerInch", "picksPerInch", "width",
      "warpShrinkagePct", "weftShrinkagePct", "warpWastagePct", "weftWastagePct",
      "warpYarnRate", "weftYarnRate", "commissionPct", "inputPerPick",
      "perPickRate", "packingCost", "freightCost", "offGradePct",
      "offGradeRecovery", "loomRpm", "loomEfficiencyPct", "pickInsertion",
      "widthsPerLoom", "numberOfLooms", "totalOrder", "inputInflow", "targetPrice",
    ];
    final missing = requiredNumericKeys.where((k) => values[k] == null).toList();
    if (warpBlend.isEmpty || weave.isEmpty || missing.isNotEmpty) {
      setState(() {
        _greyFabricRate = 0;
        _loomInFlow = 0;
      });
      context.read<CostingProvider>().clear();
      return;
    }

    final rate = SizingRatesRepository.instance.lookup(
      count: values["warpCount"]!,
      ply: values["ply"]!,
      blend: warpBlend,
    );

    if (rate == null) {
      setState(() {
        _greyFabricRate = 0;
        _loomInFlow = 0;
        _controllers["sizingCostPerKg"]!.text = "u2014";
      });
      context.read<CostingProvider>().clear();
      return;
    }
    _controllers["sizingCostPerKg"]!.text = rate.perKg.toStringAsFixed(2);

    final input = InputModel(
      warpBlend: warpBlend,
      ply: values["ply"]!,
      warpCount: values["warpCount"]!,
      weftCount: values["weftCount"]!,
      endsPerInch: values["endsPerInch"]!,
      picksPerInch: values["picksPerInch"]!,
      width: values["width"]!,
      weave: weave,
      selvedge: selvedge,
      writing: writing,
      warpShrinkagePct: values["warpShrinkagePct"]!,
      weftShrinkagePct: values["weftShrinkagePct"]!,
      warpWastagePct: values["warpWastagePct"]!,
      weftWastagePct: values["weftWastagePct"]!,
      warpYarnRate: values["warpYarnRate"]!,
      weftYarnRate: values["weftYarnRate"]!,
      sizingCostPerKg: rate.perKg,
      commissionPct: values["commissionPct"]!,
      offGradePct: values["offGradePct"]!,
      offGradeRecovery: values["offGradeRecovery"]!,
      loomRpm: values["loomRpm"]!,
      loomEfficiencyPct: values["loomEfficiencyPct"]!,
      pickInsertion: values["pickInsertion"]!,
      widthsPerLoom: values["widthsPerLoom"]!,
      numberOfLooms: values["numberOfLooms"]!,
      totalOrder: values["totalOrder"]!,
      inputInflow: values["inputInflow"]!,
      targetPrice: values["targetPrice"]!,
      perPickRate: values["perPickRate"]!,
      packingCost: values["packingCost"]!,
      freightCost: values["freightCost"]!,
      inputPerPick: values["inputPerPick"]!,
    );

    final output = CalculationEngine.calculate(
      input: input,
      sizingCostPerKg: rate.perKg,
    );

    setState(() {
      _greyFabricRate = output.greyFabricRate;
      _loomInFlow = output.loomInFlow;
    });
    context.read<CostingProvider>().update(output);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
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
        onChanged: _recalculate,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeadlineBanner(
                greyFabricRate: _greyFabricRate,
                loomInFlow: _loomInFlow,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Fabric specification', [
                      _field('warpBlend', 'Warp blend', type: FieldType.text, fullWidth: true),
                      _field('ply', 'Ply'),
                      _field('warpCount', 'Warp count (Ne)'),
                      _field('weftCount', 'Weft count (Ne)'),
                      _field('endsPerInch', 'Ends per inch'),
                      _field('picksPerInch', 'Picks per inch'),
                      _field('width', 'Width'),
                      _field('weave', 'Weave', type: FieldType.text),
                      _field('selvedge', 'Selvedge', type: FieldType.text),
                      _field('writing', 'Writing', type: FieldType.text),
                    ]),
                    _section('Shrinkage & wastage', [
                      _field('warpShrinkagePct', 'Warp shrinkage %'),
                      _field('weftShrinkagePct', 'Weft shrinkage %'),
                      _field('warpWastagePct', 'Warp wastage %'),
                      _field('weftWastagePct', 'Weft wastage %'),
                    ]),
                    _section('Rates & costing', [
                      _field('warpYarnRate', 'Warp yarn rate'),
                      _field('weftYarnRate', 'Weft yarn rate'),
                      _field('sizingCostPerKg', 'Sizing cost / kg', readOnly: true),
                      _field('commissionPct', 'Commission %'),
                      _field('inputPerPick', 'Input per pick'),
                      _field('perPickRate', 'Per pick rate'),
                      _field('packingCost', 'Packing cost'),
                      _field('freightCost', 'Freight cost'),
                    ]),
                    _section('Off grade', [
                      _field('offGradePct', 'Off grade %'),
                      _field('offGradeRecovery', 'Off grade recovery'),
                    ]),
                    _section('Loom & production', [
                      _field('loomRpm', 'Loom RPM'),
                      _field('loomEfficiencyPct', 'Loom efficiency %'),
                      _field('pickInsertion', 'Pick insertion'),
                      _field('widthsPerLoom', 'Widths / loom'),
                      _field('numberOfLooms', 'No. of looms'),
                      _field('totalOrder', 'Total order'),
                      _field('inputInflow', 'Input inflow'),
                      _field('targetPrice', 'Target price'),
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
        tooltip: 'Fill fields with voice',
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

  /// Builds one field card sized for the 2-column grid. fullWidth fields
  /// (like Warp Blend) take the entire row; everything else takes
  /// roughly half, accounting for the 8px gap between columns.
  Widget _field(
      String key,
      String label, {
        FieldType type = FieldType.number,
        bool fullWidth = false,
        bool readOnly = false,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32; // 16px padding each side
    final halfWidth = (usableWidth - 8) / 2; // 8px gap between columns

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