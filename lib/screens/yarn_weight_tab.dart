/// yarn_weight_tab.dart
/// -----------------------------------------------------------------------
/// Tab 2 of 4 inside the Outputs screen — the "Yarn Weight (Shrinkage +
/// Wastage)" and "Yarn Weight (Only Shrinkage)" blocks from the Costing
/// sheet, plus Warp KG/Mtr.
///
/// Grouped exactly as the Excel sheet groups them: one block including
/// both shrinkage AND wastage, a second block with shrinkage only — so
/// the user can see the wastage contribution by comparing the two.
/// Additional Warp/Weft rows are included even when 0 (no additional
/// yarn configured) since the Excel sheet always shows them too.
///
/// Unit: all weights here are in lbs/yard (the costing sheet's native
/// unit for these fields, consistent with the Ne yarn count convention
/// used throughout Section A). Warp KG/Mtr is its own distinct unit.
library;

import 'package:flutter/material.dart';
import '../models/output_model.dart';
import '../widgets/result_list_item.dart';

class YarnWeightTab extends StatelessWidget {
  final OutputModel output;

  const YarnWeightTab({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ResultSection(
          title: 'Yarn Weight (Shrinkage + Wastage)',
          children: [
            ResultListItem(
              label: 'Warp Weight',
              value: output.warpWeightShrinkageWastage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Weft Weight',
              value: output.weftWeightShrinkageWastage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Additional Warp Weight',
              value: output.additionalWarpWeightShrinkageWastage
                  .toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Additional Weft Weight',
              value: output.additionalWeftWeightShrinkageWastage
                  .toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
          ],
        ),
        ResultSection(
          title: 'Yarn Weight (Only Shrinkage)',
          children: [
            ResultListItem(
              label: 'Warp Weight',
              value: output.warpWeightOnlyShrinkage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Weft Weight',
              value: output.weftWeightOnlyShrinkage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Additional Warp Weight',
              value:
              output.additionalWarpWeightOnlyShrinkage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
            ResultListItem(
              label: 'Additional Weft Weight',
              value:
              output.additionalWeftWeightOnlyShrinkage.toStringAsFixed(4),
              unit: 'lbs/yd',
            ),
          ],
        ),
        ResultSection(
          title: 'Per Metre',
          children: [
            ResultListItem(
              label: 'Warp KG/Mtr',
              value: output.warpKgPerMtr.toStringAsFixed(4),
              unit: 'kg/mtr',
              emphasize: true,
            ),
          ],
        ),
      ],
    );
  }
}