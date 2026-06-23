/// settings_screen.dart
/// -----------------------------------------------------------------------
/// Full Settings screen — reachable from the bottom nav AND from the
/// sidebar drawer. Embeds the existing theme picker (Light/Dark + 5
/// accent swatches) plus wired-up rows for:
///   - Clear history  → confirmation dialog → HistoryRepository.clearAll()
///   - Share current  → ShareService.shareCostingSheet() with latest
///                      calculation (Excel + PDF), disabled if nothing
///                      has been calculated yet
///   - Voice language → still a placeholder (Phase 6)
library;

import 'main_nav_shell.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/theme_picker_section.dart';
import '../services/history_repository.dart';
import '../services/share_service.dart';
import '../models/history_entry_model.dart';
import '../theme/costing_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSharing = false;

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This will permanently delete all saved calculations. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await HistoryRepository.instance.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('History cleared')),
    );
  }

  Future<void> _shareCurrentCalculation() async {
    final costingProvider = context.read<CostingProvider>();
    final input = costingProvider.lastInput;
    final output = costingProvider.output;
    if (input == null || output == null) return;

    setState(() => _isSharing = true);
    try {
      final entry = HistoryEntry.now(input: input, output: output);
      await ShareService.shareCostingSheet(entry);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming in a later phase')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCalculation = context.watch<CostingProvider>().output != null;

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
          // Brand header
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

          const ThemePickerSection(),
          const SizedBox(height: 20),

          const _SectionLabel('Voice & data'),
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
                  iconColor: colorScheme.error,
                  onTap: _clearHistory,
                ),
                const Divider(height: 1),
                _SettingsRow(
                  icon: _isSharing ? Icons.hourglass_top : Icons.share_outlined,
                  label: 'Share current calculation',
                  subtitle: hasCalculation
                      ? 'Share as Excel + PDF'
                      : 'Fill in the Costing form first',
                  iconColor: hasCalculation
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  onTap: hasCalculation && !_isSharing
                      ? _shareCurrentCalculation
                      : () {},
                ),
              ],
            ),
          ),
        ],
      ),
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