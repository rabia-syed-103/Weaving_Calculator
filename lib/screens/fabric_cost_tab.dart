/// fabric_cost_tab.dart
/// -----------------------------------------------------------------------
/// Tab 1 of 4 inside the Outputs screen — "Section B" of the costing
/// sheet ("Fabric Cost – Yarn – Sizing – Weaving – Other").
///
/// Read-only. Takes the live OutputModel and lays its fields out as
/// grouped result lists, matching the Excel sheet's grouping:
///   - Yarn Cost (warp / weft / total)
///   - Sizing & Weaving
///   - Other costs (off grade %, commission)
///
/// All money figures are PKR/mtr — that's the unit basis for every cost
/// field on the costing sheet (grey fabric rate itself is PKR/mtr too).
library;

import 'package:flutter/material.dart';
import '../models/output_model.dart';
import '../widgets/result_list_item.dart';

class FabricCostTab extends StatelessWidget {
  final OutputModel output;

  const FabricCostTab({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ResultSection(
          title: 'Yarn Cost',
          children: [
            ResultListItem(
              label: 'Yarn Warp Cost',
              value: output.yarnWarpCost.toStringAsFixed(2),
              unit: 'PKR/mtr',
            ),
            ResultListItem(
              label: 'Yarn Weft Cost',
              value: output.yarnWeftCost.toStringAsFixed(2),
              unit: 'PKR/mtr',
            ),
            ResultListItem(
              label: 'Total Yarn Cost',
              value: output.totalYarnCost.toStringAsFixed(2),
              unit: 'PKR/mtr',
              emphasize: true,
            ),
          ],
        ),
        ResultSection(
          title: 'Sizing & Weaving',
          children: [
            ResultListItem(
              label: 'Sizing Cost Per Mtr',
              value: output.sizingCostPerMtr.toStringAsFixed(2),
              unit: 'PKR/mtr',
            ),
            ResultListItem(
              label: 'Weaving Cost',
              value: output.weavingCost.toStringAsFixed(2),
              unit: 'PKR/mtr',
            ),
          ],
        ),
        ResultSection(
          title: 'Other',
          children: [
            ResultListItem(
              label: 'Off Grade %',
              value: output.offGradePct.toStringAsFixed(2),
              unit: '%',
            ),
            ResultListItem(
              label: 'Commission Cost',
              value: output.commissionCost.toStringAsFixed(2),
              unit: 'PKR/mtr',
            ),
          ],
        ),
      ],
    );
  }
}