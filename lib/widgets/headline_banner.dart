/// headline_banner.dart
/// -----------------------------------------------------------------------
/// The fixed Grey Fabric Rate / Loom In Flow card — always visible at the
/// top of the Input Screen (and, per the project manual, should also be
/// pinned on the Output tabs screen — Sara's task in Phase 3).
library;

import 'package:flutter/material.dart';

class HeadlineBanner extends StatelessWidget {
  final double greyFabricRate;
  final double loomInFlow;

  const HeadlineBanner({
    super.key,
    required this.greyFabricRate,
    required this.loomInFlow,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'Grey Fabric Rate',
              value: greyFabricRate.toStringAsFixed(2),
              unit: 'PKR / mtr',
              color: colorScheme.onPrimary,
            ),
          ),
          Container(
            width: 0.5,
            height: 40,
            color: colorScheme.onPrimary.withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _Stat(
              label: 'Loom In Flow',
              value: loomInFlow.toStringAsFixed(0),
              unit: 'PKR / day',
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}