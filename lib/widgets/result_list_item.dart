/// result_list_item.dart
/// -----------------------------------------------------------------------
/// Read-only row used inside the 4 Output tab screens (Fabric Cost, Yarn
/// Weight, Production & Requirements, Cover Factor — Rabia's Step 9).
///
/// Mirrors the visual language of InputFieldCard (same surface color,
/// border, radius) so the Output tabs feel like a natural continuation
/// of the Input screen rather than a different app. Difference: no
/// TextFormField, since these are display-only results, not editable
/// inputs.
///
/// `ResultSection` groups a header (e.g. "Yarn Cost") above a card that
/// contains one or more `ResultListItem` rows, with a divider between
/// rows — this matches how the Excel sheet groups related outputs (e.g.
/// "B. Fabric Cost – Yarn – Sizing – Weaving – Other") under one
/// labelled block instead of a flat list.
library;

import 'package:flutter/material.dart';

class ResultListItem extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  /// Highlights the row (bold value, tinted background) for totals/
  /// summary figures — e.g. Total Yarn Cost, Total Cover Factor.
  final bool emphasize;

  const ResultListItem({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: emphasize
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(
              unit!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled card grouping several [ResultListItem] rows, with thin
/// dividers between them — the building block each output tab is made
/// of.
class ResultSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ResultSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colorScheme.outlineVariant,
                      indent: 14,
                      endIndent: 14,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}