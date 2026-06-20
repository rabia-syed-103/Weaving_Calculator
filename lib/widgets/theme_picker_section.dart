/// theme_picker_section.dart
/// -----------------------------------------------------------------------
/// The Light/Dark toggle + 5 accent-color swatches — extracted from
/// Rabia's original widgets/settings_drawer.dart so the SAME widget can
/// be embedded both in SettingsScreen (the new full settings page) and
/// in the sidebar drawer, without copy-pasting the theme logic twice.
///
/// Visual styling and behavior are unchanged from the original drawer —
/// this is a refactor (move + rename), not a redesign.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class ThemePickerSection extends StatelessWidget {
  const ThemePickerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final dark = themeProvider.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Appearance'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                icon: Icons.light_mode_outlined,
                label: 'Light',
                selected: !dark,
                onTap: () => themeProvider.setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                icon: Icons.dark_mode_outlined,
                label: 'Dark',
                selected: dark,
                onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _SectionLabel('Accent theme'),
        const SizedBox(height: 8),
        ...AccentColor.values.map((accent) {
          final isSelected = themeProvider.accent == accent;
          final swatchColor = AppTheme.seedColors[accent]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => themeProvider.setAccent(accent),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: swatchColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(accent.label),
                    const Spacer(),
                    if (isSelected)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}