/// input_field_card.dart
/// -----------------------------------------------------------------------
/// One field in the 2-column input grid. No per-field mic icon — voice
/// input is handled by the single FAB on InputScreen (see
/// VoiceInputController, Phase 6). This widget is purely the visual
/// field + validation.
library;

import 'package:flutter/material.dart';

enum FieldType { number, text }

class InputFieldCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FieldType type;

  /// If true, this card spans both grid columns (use for longer text
  /// fields like Warp Blend). Default false = half-width.
  final bool fullWidth;

  /// Marks the field read-only with a muted look — used for fields like
  /// Sizing Cost Per Kg that come from the SizingRatesRepository lookup
  /// rather than direct user entry.
  final bool readOnly;

  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const InputFieldCard({
    super.key,
    required this.label,
    required this.controller,
    this.type = FieldType.number,
    this.fullWidth = false,
    this.readOnly = false,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: readOnly
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: type == FieldType.number
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: readOnly
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            validator: validator ?? (type == FieldType.number ? _defaultNumberValidator : null),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  static String? _defaultNumberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Enter a number';
    return null;
  }
}