/// settings_screen.dart
/// -----------------------------------------------------------------------
/// Full Settings screen — reachable from the bottom nav AND from the
/// sidebar drawer. Embeds the existing theme picker (Light/Dark + 5
/// accent swatches, built by Rabia in widgets/theme_picker_section.dart)
/// plus placeholder rows for the remaining settings from the original
/// project mockup: voice language, clear history, export history.
///
/// NOTE ON SCOPE: voice language / clear history / export history are
/// placeholders (show a "coming soon" snackbar on tap) because their
/// real functionality depends on later phases:
///   - Voice language  -> Phase 6 (speech_to_text integration)
///   - Clear history   -> Phase 5 (Hive storage)
///   - Export history  -> Phase 5 (Hive storage)
/// Wiring them for real is the responsibility of whoever builds those
/// phases — this screen just gives them a fixed place to live.
library;
import 'main_nav_shell.dart';

import 'package:flutter/material.dart';
import '../widgets/theme_picker_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Brand header — logo + app name, matches the original mockup's
          // "ST" badge + SadeedTex name + version line.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ST',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SadeedTex',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fabric Costing App v1.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme picker — reuses Rabia's existing widget so there's only
          // ONE place the Light/Dark + accent logic lives, not two copies.
          const ThemePickerSection(),
          const SizedBox(height: 20),

          _SectionLabel('Voice & data'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsRow(
                  icon: Icons.translate,
                  label: 'Voice language',
                  subtitle: 'Urdu / English',
                  onTap: () => _comingSoon(context, 'Voice language selection'),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.delete_outline,
                  label: 'Clear history',
                  subtitle: 'Delete all saved calculations',
                  iconColor: Theme.of(context).colorScheme.error,
                  onTap: () => _comingSoon(context, 'Clear history'),
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: Icons.download_outlined,
                  label: 'Export history',
                  subtitle: 'Save as JSON file',
                  onTap: () => _comingSoon(context, 'Export history'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming in a later phase')),
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

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? colorScheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}