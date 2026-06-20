/// cover_factor_tab.dart
/// -----------------------------------------------------------------------
/// Tab 4 of 4 inside the Outputs screen — "Section D" of the costing
/// sheet ("Cover Factor, Reed Space & Tape Length").
///
/// Grouped as: Cover Factor (warp/weft/2nd warp/2nd weft/total) ->
/// Reed Space & Tape Length -> Weight & Container capacity.
///
/// Reed Space and Tape Length keep their Excel units (inches, metres).
/// Wt Grams per Metre is grams; the two container fields are in metres
/// of fabric that fit a 20ft / 40ft container, per the sheet.
library;

import 'package:flutter/material.dart';
import '../models/output_model.dart';
import '../widgets/result_list_item.dart';

class CoverFactorTab extends StatelessWidget {
  final OutputModel output;

  const CoverFactorTab({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ResultSection(
          title: 'Cover Factor',
          children: [
            ResultListItem(
              label: 'Cover Factor – Warp',
              value: output.coverFactorWarp.toStringAsFixed(2),
            ),
            ResultListItem(
              label: 'Cover Factor – 2nd Warp',
              value: output.coverFactorSecondWarp.toStringAsFixed(2),
            ),
            ResultListItem(
              label: 'Cover Factor – Weft',
              value: output.coverFactorWeft.toStringAsFixed(2),
            ),
            ResultListItem(
              label: 'Cover Factor – 2nd Weft',
              value: output.coverFactorSecondWeft.toStringAsFixed(2),
            ),
            ResultListItem(
              label: 'Total Cover Factor',
              value: output.totalCoverFactor.toStringAsFixed(2),
              emphasize: true,
            ),
          ],
        ),
        ResultSection(
          title: 'Reed Space & Tape Length',
          children: [
            ResultListItem(
              label: 'Reed Space',
              value: output.reedSpaceInches.toStringAsFixed(2),
              unit: 'inches',
            ),
            ResultListItem(
              label: 'Tape Length',
              value: output.tapeLengthMtr.toStringAsFixed(2),
              unit: 'mtr',
            ),
          ],
        ),
        ResultSection(
          title: 'Weight & Container Capacity',
          children: [
            ResultListItem(
              label: 'Wt Grams per Metre',
              value: output.wtGramsPerMetre.toStringAsFixed(2),
              unit: 'g/mtr',
            ),
            ResultListItem(
              label: 'Container – 20ft',
              value: output.container20ftMtrs.toStringAsFixed(0),
              unit: 'mtrs',
            ),
            ResultListItem(
              label: 'Container – 40ft',
              value: output.container40ftMtrs.toStringAsFixed(0),
              unit: 'mtrs',
            ),
          ],
        ),
      ],
    );
  }
}