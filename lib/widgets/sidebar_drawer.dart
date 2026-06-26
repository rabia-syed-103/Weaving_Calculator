/// sidebar_drawer.dart
/// -----------------------------------------------------------------------
/// The hamburger-menu sidebar — full navigation menu, NOT just theme
/// settings (that's the old SettingsDrawer, now superseded by this for
/// the drawer's role; theme picking itself still lives in
/// theme_picker_section.dart and is reused inside SettingsScreen).
///
/// Matches the original project mockup: Costing, Fabric Cost, Yarn
/// Weight, Production, Cover Factor, History, Settings — all in one
/// navigation list.
///
/// HOW SUB-TAB NAVIGATION WORKS:
/// Fabric Cost / Yarn Weight / Production / Cover Factor aren't separate
/// screens — they're tabs INSIDE the Outputs screen (project manual,
/// Section 3.2). So tapping one of those four here needs to do two
/// things: (1) switch the bottom nav to the Outputs tab, (2) tell the
/// Outputs screen which of its 4 sub-tabs to open.
///
/// Until Rabia's Step 9 (the real TabBar inside Outputs) exists, this
/// drawer just navigates to the Outputs placeholder and ignores which
/// sub-tab was tapped — see the TODO in onDestinationTap. Once the real
/// tabbed Outputs screen exists, swap that TODO for an actual tab-index
/// callback (e.g. via a shared TabController or a callback passed down
/// from MainNavShell).
library;

import 'package:flutter/material.dart';

/// Which top-level destination the drawer should switch the bottom nav
/// to. Matches MainNavShell's tab order: Costing, Outputs, History,
/// Settings.
enum DrawerDestination { costing, outputs, history, settings }

class SidebarDrawer extends StatelessWidget {
  /// Called when the user taps any nav item. [outputsSubTab] is non-null
  /// only when the tapped item is one of the 4 Outputs sub-sections
  /// (Fabric Cost = 0, Yarn Weight = 1, Production = 2, Cover Factor = 3)
  /// — pass it through once the real tabbed Outputs screen exists.
  final void Function(DrawerDestination destination, {int? outputsSubTab})
  onNavigate;

  const SidebarDrawer({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: colorScheme.primary,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/sadeedtex_logo.png',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SadeedTex',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      Text(
                        'Fabric Costing v1',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.calculate_outlined,
                    label: 'Costing inputs',
                    onTap: () => _navigate(context, DrawerDestination.costing),
                  ),
                  _DrawerItem(
                    icon: Icons.attach_money,
                    label: 'Fabric cost',
                    onTap: () => _navigate(
                      context,
                      DrawerDestination.outputs,
                      outputsSubTab: 0,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.scale_outlined,
                    label: 'Yarn weight',
                    onTap: () => _navigate(
                      context,
                      DrawerDestination.outputs,
                      outputsSubTab: 1,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.precision_manufacturing_outlined,
                    label: 'Production',
                    onTap: () => _navigate(
                      context,
                      DrawerDestination.outputs,
                      outputsSubTab: 2,
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.straighten,
                    label: 'Cover factor',
                    onTap: () => _navigate(
                      context,
                      DrawerDestination.outputs,
                      outputsSubTab: 3,
                    ),
                  ),
                  const Divider(height: 1),
                  _DrawerItem(
                    icon: Icons.history,
                    label: 'History',
                    onTap: () => _navigate(context, DrawerDestination.history),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _navigate(context, DrawerDestination.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigate(
      BuildContext context,
      DrawerDestination destination, {
        int? outputsSubTab,
      }) {
    Navigator.of(context).pop(); // close the drawer first
    onNavigate(destination, outputsSubTab: outputsSubTab);
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    );
  }
}