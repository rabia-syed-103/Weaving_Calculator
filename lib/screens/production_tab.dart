/// production_tab.dart
/// -----------------------------------------------------------------------
/// Tab 3 of 4 inside the Outputs screen — "Section C" of the costing
/// sheet ("Production – Completion – Yarn Requirement").
///
/// Grouped as: Production rate -> Completion timeline -> Bags required.
/// completionDate comes in as a DateTime (OutputModel already parses
/// Excel's serial date into a real DateTime, per its fromJson/toJson),
/// so it's formatted here as dd MMM yyyy rather than shown raw.
///
/// 2nd Warp/Weft Bags Required are shown even when 0 — matches the
/// Excel sheet, which always displays these rows whether or not
/// additional yarn is configured.
library;

import 'package:flutter/material.dart';
import '../models/output_model.dart';
import '../widgets/result_list_item.dart';

class ProductionTab extends StatelessWidget {
  final OutputModel output;

  const ProductionTab({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ResultSection(
          title: 'Production Rate',
          children: [
            ResultListItem(
              label: 'Per Day Per Loom Production',
              value: output.perDayPerLoomProduction.toStringAsFixed(2),
              unit: 'mtr/day',
            ),
            ResultListItem(
              label: 'Daily Production (All Looms)',
              value: output.dailyProductionAllLooms.toStringAsFixed(2),
              unit: 'mtr/day',
              emphasize: true,
            ),
          ],
        ),
        ResultSection(
          title: 'Completion',
          children: [
            ResultListItem(
              label: 'Days Required for Completion',
              value: output.daysRequiredForCompletion.toStringAsFixed(2),
              unit: 'Days',
            ),
            ResultListItem(
              label: 'Completion Date',
              value: _formatDate(output.completionDate),
            ),
          ],
        ),
        ResultSection(
          title: 'Yarn Requirement (Bags)',
          children: [
            ResultListItem(
              label: 'Warp Bags Required',
              value: output.warpBagsRequired.toStringAsFixed(0),
              unit: 'bags',
            ),
            ResultListItem(
              label: '2nd Warp Bags Required',
              value: output.secondWarpBagsRequired.toStringAsFixed(0),
              unit: 'bags',
            ),
            ResultListItem(
              label: 'Weft Bags Required',
              value: output.weftBagsRequired.toStringAsFixed(0),
              unit: 'bags',
            ),
            ResultListItem(
              label: '2nd Weft Bags Required',
              value: output.secondWeftBagsRequired.toStringAsFixed(0),
              unit: 'bags',
            ),
          ],
        ),
      ],
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${_months[date.month - 1]} ${date.year}';
  }
}